//
//  ChatService.swift
//  Yukum
//

import Foundation // [SWIFT] ağ araçları

// ┌─ BAĞLANTI HARİTASI: ChatService (sohbet uçları) ─────────────────────────────────
// │ ÇAĞIRAN   : ViewModels/ChatViewModel (messages, send, clear, complete) — ChatServicing sözleşmesi üzerinden
// │ KULLANIR  : Networking/APIClient | MODEL: ChatMessage, SendMessageRequest
// │ API       : backend MessagesController: GET/POST/DELETE /api/v1/offers/{id}/messages | OffersController: POST /offers/{id}/complete
// │ SAHTESİ   : YukumTests/Support/FakeChatService.swift
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA: teklif sohbeti uçlarıyla konuşur. İsteğin kendisi (jeton, 401'de yenileme, hata çevirme) Networking/APIClient.swift'te.
// FONKSİYON HARİTASI: messages = mesajları ÇEKME (GET) | send = mesaj GÖNDERME (POST) | clear = mesajları TEMİZLE (DELETE, yalnız kendi görünümümden) | complete = İŞİ BİTİR (POST)
// BAĞLANTI: Views/ChatView.swift çağırır | kalıplar: Models/Chat/ | API: backend MessagesController ve OffersController
struct ChatService { // ChatService [BİZİM] ad

    private let api = APIClient.shared

    // messages: bir teklifin sohbetindeki tüm mesajları getirir (eskiden yeniye) | yalnız teklifin iki tarafı görür
    // ÇAĞIRAN: Views/ChatView.swift → loadMessages() | ekran açılınca ve 3 saniyede bir çağrılır (yenileme) | API: GET /api/v1/offers/{offerId}/messages
    // ⮕ ZİNCİR: ViewModels/ChatViewModel.load() ← startPolling() döngüsü (3 sn) + send/clear sonrası ← Views/ChatView .task | API: GET /api/v1/offers/{id}/messages | DÖNEN: [ChatMessage]
    func messages(offerId: String) async throws -> [ChatMessage] { // offerId: hangi teklifin sohbeti
        try await api.send(.get, "/api/v1/offers/\(offerId)/messages", fallback: "Mesajlar alınamadı.")
    }

    // send: sohbete mesaj yazar | _ body: yazılan mesaj paketi ({"text":"..."}) | reddedilmiş/tamamlanmış/iptal edilmiş tekliflerde API 409 verir
    // ÇAĞIRAN: Views/ChatView.swift → Gönder düğmesi | API: POST /api/v1/offers/{offerId}/messages
    // ⮕ ZİNCİR: ViewModels/ChatViewModel.send() ← Views/ChatView "Gönder" | API: POST /api/v1/offers/{id}/messages | GİDEN: SendMessageRequest | DÖNEN: yok
    func send(offerId: String, _ body: SendMessageRequest) async throws {
        try await api.sendNoContent(.post, "/api/v1/offers/\(offerId)/messages", body: body, fallback: "Mesaj gönderilemedi.") // cevap 201 + mesaj, ama ekran listeyi yeniden çektiği için içeriği kullanmıyoruz
    }

    // clear: "Mesajları Temizle" | mesajları YALNIZ KENDİ görünümümden siler, karşı taraf görmeye devam eder (sunucu mesajları benim için "gizli" işaretler, silmez)
    // ÇAĞIRAN: Views/ChatView.swift sağ üst menü | API: DELETE /api/v1/offers/{offerId}/messages
    // ⮕ ZİNCİR: ViewModels/ChatViewModel.clear() ← Views/ChatView menü "Mesajları Temizle" | API: DELETE /api/v1/offers/{id}/messages | DÖNEN: yok
    func clear(offerId: String) async throws {
        try await api.sendNoContent(.delete, "/api/v1/offers/\(offerId)/messages", fallback: "Mesajlar silinemedi.")
    }

    // complete: "İşi Bitir ve Sil" | kabul edilmiş işi tamamlar
    // NE İŞE YARAR: teklif İKİ TARAFTA "Tamamlandı" olur, sohbet iki tarafta yazmaya kilitlenir | silme yalnız BENİM tarafımda: teklif geçmişimden ve mesajlarım silinir
    // ÇAĞIRAN: Views/ChatView.swift sağ üst menü (yalnız kabul edilmiş tekliflerde) | API: POST /api/v1/offers/{offerId}/complete
    // ⮕ ZİNCİR: ViewModels/ChatViewModel.complete() ← Views/ChatView menü "İşi Bitir ve Sil" | API: POST /api/v1/offers/{id}/complete | DÖNEN: yok
    func complete(offerId: String) async throws {
        try await api.sendNoContent(.post, "/api/v1/offers/\(offerId)/complete", fallback: "İş tamamlanamadı.")
    }
}

// ChatService, kendi sözleşmesini karşılar (Services/Protocols/): ViewModel'ler somut sınıfa değil sözleşmeye bağlıdır, testte sahtesi verilir
extension ChatService: ChatServicing {}
