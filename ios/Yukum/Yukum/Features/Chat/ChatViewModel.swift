//
//  ChatViewModel.swift
//  Yukum
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: ChatViewModel ───────────────────────────────────────────────
// │ EKRAN     : Features/Chat/ChatView (@State private var viewModel, init(context:))
// │ SERVİS    : Features/Chat/ChatServicing → ChatService
// │ MODEL     : ChatMessage, SendMessageRequest, ChatContext (açılış bilgisi)
// │ AKIŞ      : View .task → startPolling() → 3 sn'de bir load() → messages → balonlar | Gönder → send() → servis → load()
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: sohbet ekranının durumu ve mantığı (mesajlar, taslak, hata, kilit, gönderme, temizleme, işi bitirme, otomatik yenileme)
// BAĞLANTI: Features/Chat/ChatView.swift kullanır | servis: Features/Chat/ChatService.swift (ChatServicing sözleşmesi)
// ⮕ KULLANIM [ChatViewModel]: kullanır: ChatView › viewModel, ChatView › init(), ChatViewModelTests (test)
@Observable // @Observable [SWIFT]: sınıfı gözlemlenebilir yapar: değişkenleri değişince onları okuyan ekranlar kendiliğinden yenilenir
final class ChatViewModel {

    // ⮕ ZİNCİR: Features/Chat/ChatView: başlık (context.title) ve menü kuralları | gelen: bir üstteki ekranın navigationDestination'ı (ChatContext.forCarrier / forShipperPending / forShipperHistory)
    // ⮕ KULLANIM [context]: okur: ChatViewModel › canWrite, ChatViewModel › canComplete, ChatViewModel › load(), ChatViewModel › send(), ChatViewModel › clear(), ChatViewModel › complete() … +1
    let context: ChatContext
    // ⮕ KULLANIM [service]: okur: ChatViewModel › load(), ChatViewModel › send(), ChatViewModel › clear(), ChatViewModel › complete()
    private let service: ChatServicing
    // ⮕ KULLANIM [pollInterval]: okur: ChatViewModel › startPolling()
    private let pollInterval: Duration // Duration [SWIFT]: süre | yenileme aralığı (testte kısa verilir)

    // ⮕ ZİNCİR: Features/Chat/ChatView: ForEach(viewModel.messages) → balonlar (isMine: sağ/mavi, değilse sol/gri) | DOLDURAN: load() ← ChatService.messages | MODEL: [ChatMessage]
    // ⮕ KULLANIM [messages]: YAZAR: ChatViewModel › load() | okur: ChatView › body, ChatViewModelTests (test)
    var messages: [ChatMessage] = [] // balonlar bundan çizilir
    // ⮕ ZİNCİR: Features/Chat/ChatView: TextField("Mesaj Yaz", text: $viewModel.draft) — yazılan her harf buraya gider (@Bindable) | send() okur, boşaltır
    // ⮕ KULLANIM [draft]: okur: ChatViewModel › canSend, ChatViewModel › send(), ChatViewModelTests (test) | YAZAR: ChatViewModel › send(), ChatViewModelTests (test) | bağlar(okur+yazar): ChatView › body
    var draft = "" // yazma kutusundaki henüz gönderilmemiş metin
    // ⮕ ZİNCİR: Features/Chat/ChatView: if let errorMessage → kırmızı küçük yazı | DOLDURAN: load/send/clear/complete catch'leri
    // ⮕ KULLANIM [errorMessage]: YAZAR: ChatViewModel › load(), ChatViewModel › send(), ChatViewModel › clear(), ChatViewModel › complete() | okur: ChatViewModelTests (test)
    var errorMessage: String? // kırmızı hata yazısı
    // locked: sohbet bu ekran AÇIKKEN kilitlendi mi | karşı taraf işi bitirirse/teklif reddedilirse biz yazmaya çalışınca sunucu "sohbet kapalı" der, o zaman true olur
    // NEDEN: context.canWrite ekran açılırken verilen sabit değer; durum açıkken değişirse onu yakalayan bu
    // ⮕ ZİNCİR: send() sunucudan "sohbet kapalı" cevabı alınca true olur (karşı taraf işi bitirdi/teklif reddedildi) → canWrite false → Features/Chat/ChatView yazma kutusu kapanır
    private(set) var locked = false

    // Türetilmiş değerler: ekran bunları okur (kural ViewModel'de)
    // ⮕ ZİNCİR: Features/Chat/ChatView: if viewModel.canWrite { yazma kutusu } else { "Bu sohbet kapalı" yazısı } | kural: context.canWrite && !locked
    // ⮕ KULLANIM [canWrite]: okur: ChatView › body, ChatViewModelTests (test)
    var canWrite: Bool { context.canWrite && !locked }
    // ⮕ ZİNCİR: Features/Chat/ChatView: menüdeki "İşi Bitir ve Sil" yalnız bu true ise görünür | kural: context.canComplete && !locked
    // ⮕ KULLANIM [canComplete]: okur: ChatView › body, ChatViewModelTests (test), MyOffersViewModelTests (test)
    var canComplete: Bool { context.canComplete && !locked }
    // ⮕ ZİNCİR: Features/Chat/ChatView: "Gönder" düğmesi .disabled(!viewModel.canSend) — draft boşsa kilitli
    // ⮕ KULLANIM [canSend]: okur: ChatView › body, ChatViewModelTests (test)
    var canSend: Bool { !draft.trimmingCharacters(in: .whitespaces).isEmpty } // boş ya da yalnız boşluksa Gönder kilitli

    init(context: ChatContext, service: ChatServicing = ChatService(), pollInterval: Duration = .seconds(3)) {
        self.context = context
        self.service = service
        self.pollInterval = pollInterval
    }

    // startPolling: YENİLEME DÖNGÜSÜ | ekran açılınca başlar, ekran kapanınca (.task iptal edilince) kendiliğinden durur
    // POLLING: sunucu "push" yapmaz; biz birkaç saniyede bir tekrar sorarız | canlı bağlantı (SignalR/WebSocket) yerine basit yöntem
    // ⮕ ZİNCİR: Features/Chat/ChatView: .task { await viewModel.startPolling() } — ekran kapanınca task iptal edilir, döngü kendiliğinden durur | POLLING: canlı bağlantı yok, 3 sn'de bir sorarız
    // ⮕ KULLANIM [startPolling]: çağırır: ChatView › body, ChatViewModelTests (test)
    func startPolling() async { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz)
        while !Task.isCancelled { // iptal edilene kadar tekrarla | Task [SWIFT]: arka planda çalışan iş: normal koddan await kullanabilmeyi sağlar
            await load() // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
            try? await Task.sleep(for: pollInterval) // bekle | try?: iptal edilirse hata fırlatır, sessiz geç | try? [SWIFT]: hata olursa çökme, nil ver
        }
    }

    // load: mesajları API'den çekip listeye yazar
    // ⮕ ZİNCİR: startPolling döngüsü, send() ve clear() sonrası | ChatService.messages(offerId:) → [ChatMessage] → messages
    // ⮕ KULLANIM [load]: çağırır: ChatViewModel › startPolling(), ChatViewModel › send(), ChatViewModel › clear()
    func load() async {
        do {
            messages = try await service.messages(offerId: context.offerId)
        } catch {
            if let message = error.userMessage { errorMessage = message } // iptal ise (nil) yazı gösterilmez
        }
    }

    // send: Gönder düğmesi | yazılan metni API'ye yollar, sonra mesajları hemen yeniden çeker
    // ⮕ ZİNCİR: Features/Chat/ChatView: Button("Gönder") { Task { await viewModel.send() } } | ChatService.send(offerId:_:) ← SendMessageRequest(text:)
    // ⮕ KULLANIM [send]: çağırır: ChatViewModel › send(), ChatView › body, ChatService › messages(), ChatViewModelTests (test)
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
    // ⮕ ZİNCİR: Features/Chat/ChatView: menü "Mesajları Temizle" → onay penceresi "Benden Sil" | ChatService.clear(offerId:)
    // ⮕ KULLANIM [clear]: çağırır: ChatViewModel › clear(), ChatView › body, ChatViewModelTests (test), RegisterViewModelTests (test)
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
    // ⮕ ZİNCİR: Features/Chat/ChatView: menü "İşi Bitir ve Sil" → alert "Bitir ve Sil" | ChatService.complete(offerId:) | true dönerse View dismiss() ile geri döner
    // ⮕ KULLANIM [complete]: çağırır: ChatViewModel › complete(), ChatView › body, ChatViewModelTests (test)
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
