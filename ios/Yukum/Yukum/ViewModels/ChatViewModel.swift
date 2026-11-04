//
//  ChatViewModel.swift
//  Yukum
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: ChatViewModel ───────────────────────────────────────────────
// │ EKRAN     : Views/ChatView (@State private var viewModel, init(context:))
// │ SERVİS    : Services/Protocols/ChatServicing → ChatService
// │ MODEL     : ChatMessage, SendMessageRequest, ChatContext (açılış bilgisi)
// │ AKIŞ      : View .task → startPolling() → 3 sn'de bir load() → messages → balonlar | Gönder → send() → servis → load()
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: sohbet ekranının durumu ve mantığı (mesajlar, taslak, hata, kilit, gönderme, temizleme, işi bitirme, otomatik yenileme)
// BAĞLANTI: Views/ChatView.swift kullanır | servis: Services/ChatService.swift (ChatServicing sözleşmesi)
@Observable // @Observable [SWIFT]: sınıfı gözlemlenebilir yapar: değişkenleri değişince onları okuyan ekranlar kendiliğinden yenilenir
final class ChatViewModel {

    // ⮕ ZİNCİR: Views/ChatView: başlık (context.title) ve menü kuralları | gelen: bir üstteki ekranın navigationDestination'ı (ChatContext.forCarrier / forShipperPending / forShipperHistory)
    let context: ChatContext
    private let service: ChatServicing
    private let pollInterval: Duration // Duration [SWIFT]: süre | yenileme aralığı (testte kısa verilir)

    // ⮕ ZİNCİR: Views/ChatView: ForEach(viewModel.messages) → balonlar (isMine: sağ/mavi, değilse sol/gri) | DOLDURAN: load() ← ChatService.messages | MODEL: [ChatMessage]
    var messages: [ChatMessage] = [] // balonlar bundan çizilir
    // ⮕ ZİNCİR: Views/ChatView: TextField("Mesaj Yaz", text: $viewModel.draft) — yazılan her harf buraya gider (@Bindable) | send() okur, boşaltır
    var draft = "" // yazma kutusundaki henüz gönderilmemiş metin
    // ⮕ ZİNCİR: Views/ChatView: if let errorMessage → kırmızı küçük yazı | DOLDURAN: load/send/clear/complete catch'leri
    var errorMessage: String? // kırmızı hata yazısı
    // locked: sohbet bu ekran AÇIKKEN kilitlendi mi | karşı taraf işi bitirirse/teklif reddedilirse biz yazmaya çalışınca sunucu "sohbet kapalı" der, o zaman true olur
    // NEDEN: context.canWrite ekran açılırken verilen sabit değer; durum açıkken değişirse onu yakalayan bu
    // ⮕ ZİNCİR: send() sunucudan "sohbet kapalı" cevabı alınca true olur (karşı taraf işi bitirdi/teklif reddedildi) → canWrite false → Views/ChatView yazma kutusu kapanır
    private(set) var locked = false

    // Türetilmiş değerler: ekran bunları okur (kural ViewModel'de)
    // ⮕ ZİNCİR: Views/ChatView: if viewModel.canWrite { yazma kutusu } else { "Bu sohbet kapalı" yazısı } | kural: context.canWrite && !locked
    var canWrite: Bool { context.canWrite && !locked }
    // ⮕ ZİNCİR: Views/ChatView: menüdeki "İşi Bitir ve Sil" yalnız bu true ise görünür | kural: context.canComplete && !locked
    var canComplete: Bool { context.canComplete && !locked }
    // ⮕ ZİNCİR: Views/ChatView: "Gönder" düğmesi .disabled(!viewModel.canSend) — draft boşsa kilitli
    var canSend: Bool { !draft.trimmingCharacters(in: .whitespaces).isEmpty } // boş ya da yalnız boşluksa Gönder kilitli

    init(context: ChatContext, service: ChatServicing = ChatService(), pollInterval: Duration = .seconds(3)) {
        self.context = context
        self.service = service
        self.pollInterval = pollInterval
    }

    // startPolling: YENİLEME DÖNGÜSÜ | ekran açılınca başlar, ekran kapanınca (.task iptal edilince) kendiliğinden durur
    // POLLING: sunucu "push" yapmaz; biz birkaç saniyede bir tekrar sorarız | canlı bağlantı (SignalR/WebSocket) yerine basit yöntem
    // ⮕ ZİNCİR: Views/ChatView: .task { await viewModel.startPolling() } — ekran kapanınca task iptal edilir, döngü kendiliğinden durur | POLLING: canlı bağlantı yok, 3 sn'de bir sorarız
    func startPolling() async { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz)
        while !Task.isCancelled { // iptal edilene kadar tekrarla | Task [SWIFT]: arka planda çalışan iş: normal koddan await kullanabilmeyi sağlar
            await load() // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
            try? await Task.sleep(for: pollInterval) // bekle | try?: iptal edilirse hata fırlatır, sessiz geç | try? [SWIFT]: hata olursa çökme, nil ver
        }
    }

    // load: mesajları API'den çekip listeye yazar
    // ⮕ ZİNCİR: startPolling döngüsü, send() ve clear() sonrası | ChatService.messages(offerId:) → [ChatMessage] → messages
    func load() async {
        do {
            messages = try await service.messages(offerId: context.offerId)
        } catch {
            if let message = error.userMessage { errorMessage = message } // iptal ise (nil) yazı gösterilmez
        }
    }

    // send: Gönder düğmesi | yazılan metni API'ye yollar, sonra mesajları hemen yeniden çeker
    // ⮕ ZİNCİR: Views/ChatView: Button("Gönder") { Task { await viewModel.send() } } | ChatService.send(offerId:_:) ← SendMessageRequest(text:)
    func send() async {
        let text = draft.trimmingCharacters(in: .whitespaces) // baş/son boşlukları temizle
        guard !text.isEmpty else { return } // boşsa dur (düğme zaten kilitli, ikinci güvenlik) | guard [SWIFT]: şart sağlanmazsa fonksiyondan erken çık
        draft = "" // kutuyu hemen boşalt, kullanıcı beklemeden yeni mesaj yazabilir
        errorMessage = nil
        do {
            try await service.send(offerId: context.offerId, SendMessageRequest(text: text))
            await load() // 3 sn beklemeden listeyi yenile: kendi mesajım görünür
        } catch {
            draft = text // gönderilemedi, yazdığı metin kaybolmasın
            if let message = error.userMessage {
                errorMessage = message // örn. "Reddedilen teklifte sohbet kapalı."
                if message.contains("kapalı") { locked = true } // sunucu "sohbet kapalı" dediyse (karşı taraf işi bitirdi/teklif reddedildi) yazma kutusunu hemen kapat
            }
        }
    }

    // clear: "Mesajları Temizle" | mesajları YALNIZ KENDİ görünümümden siler, karşı taraf görmeye devam eder
    // ⮕ ZİNCİR: Views/ChatView: menü "Mesajları Temizle" → onay penceresi "Benden Sil" | ChatService.clear(offerId:)
    func clear() async {
        errorMessage = nil
        do {
            try await service.clear(offerId: context.offerId)
            await load() // sunucu bu kullanıcı için mesajları gizlediğinden liste boş gelir
        } catch {
            if let message = error.userMessage { errorMessage = message }
        }
    }

    // complete: "İşi Bitir ve Sil" | -> Bool: başarılı mı (ekran başarılıysa sohbetten geri döner)
    // teklif İKİ TARAFTA Tamamlandı olur, sohbet iki tarafta kilitlenir, benim listemden teklif ve mesajlar silinir
    // ⮕ ZİNCİR: Views/ChatView: menü "İşi Bitir ve Sil" → alert "Bitir ve Sil" | ChatService.complete(offerId:) | true dönerse View dismiss() ile geri döner
    func complete() async -> Bool {
        errorMessage = nil
        do {
            try await service.complete(offerId: context.offerId)
            return true
        } catch {
            if let message = error.userMessage { errorMessage = message } // örn. "Yalnız kabul edilmiş iş tamamlanabilir."
            return false
        }
    }
}
