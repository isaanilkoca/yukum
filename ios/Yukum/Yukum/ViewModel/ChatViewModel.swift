//
//  ChatViewModel.swift
//  Yukum
//

import Foundation
import Observation

// BU SINIF: sohbet ekranının durumu ve mantığı (mesajlar, taslak, hata, kilit, gönderme, temizleme, işi bitirme, otomatik yenileme)
// BAĞLANTI: View/ChatView.swift kullanır | servis: Network/ChatService.swift (ChatServicing sözleşmesi)
@Observable
final class ChatViewModel {

    let context: ChatContext
    private let service: ChatServicing
    private let pollInterval: Duration // Duration [SWIFT]: süre | yenileme aralığı (testte kısa verilir)

    var messages: [ChatMessage] = [] // balonlar bundan çizilir
    var draft = "" // yazma kutusundaki henüz gönderilmemiş metin
    var errorMessage: String? // kırmızı hata yazısı
    // locked: sohbet bu ekran AÇIKKEN kilitlendi mi | karşı taraf işi bitirirse/teklif reddedilirse biz yazmaya çalışınca sunucu "sohbet kapalı" der, o zaman true olur
    // NEDEN: context.canWrite ekran açılırken verilen sabit değer; durum açıkken değişirse onu yakalayan bu
    private(set) var locked = false

    // Türetilmiş değerler: ekran bunları okur (kural ViewModel'de)
    var canWrite: Bool { context.canWrite && !locked }
    var canComplete: Bool { context.canComplete && !locked }
    var canSend: Bool { !draft.trimmingCharacters(in: .whitespaces).isEmpty } // boş ya da yalnız boşluksa Gönder kilitli

    init(context: ChatContext, service: ChatServicing = ChatService(), pollInterval: Duration = .seconds(3)) {
        self.context = context
        self.service = service
        self.pollInterval = pollInterval
    }

    // startPolling: YENİLEME DÖNGÜSÜ | ekran açılınca başlar, ekran kapanınca (.task iptal edilince) kendiliğinden durur
    // POLLING: sunucu "push" yapmaz; biz birkaç saniyede bir tekrar sorarız | canlı bağlantı (SignalR/WebSocket) yerine basit yöntem
    func startPolling() async {
        while !Task.isCancelled { // iptal edilene kadar tekrarla
            await load()
            try? await Task.sleep(for: pollInterval) // bekle | try?: iptal edilirse hata fırlatır, sessiz geç
        }
    }

    // load: mesajları API'den çekip listeye yazar
    func load() async {
        do {
            messages = try await service.messages(offerId: context.offerId)
        } catch {
            if let message = error.userMessage { errorMessage = message } // iptal ise (nil) yazı gösterilmez
        }
    }

    // send: Gönder düğmesi | yazılan metni API'ye yollar, sonra mesajları hemen yeniden çeker
    func send() async {
        let text = draft.trimmingCharacters(in: .whitespaces) // baş/son boşlukları temizle
        guard !text.isEmpty else { return } // boşsa dur (düğme zaten kilitli, ikinci güvenlik)
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
