//
//  ChatMessage.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: ChatMessage (sohbet mesajı) ─────────────────────────────────
// │ MODEL     : Sohbetteki tek mesaj: metin, zaman, "benim mi" bilgisi
// │ ÜRETEN    : Models/Services/ChatService.messages ← GET /api/v1/offers/{id}/messages
// │ SAKLAYAN  : ViewModels/ChatViewModel.messages → Views/ChatView (balonlar; isMine true ise sağda mavi, değilse solda gri)
// └──────────────────────────────────────────────────────────────────────

// ChatMessage: sohbetteki TEK MESAJIN kalıbı (GET listesindeki her eleman).
// NE İŞE YARAR: API'den gelen JSON her mesaj için bu struct'a çevrilir | Decodable [SWIFT]: JSON → struct | Identifiable: benzersiz id'si var, List/ForEach'te id: yazmak gerekmez
// NEREDE KULLANILIR: ChatService.messages() bu struct'ın listesini döner → Views/ChatView.swift balonları çizer
// ⮕ KULLANIM [ChatMessage]: kullanır: ChatViewModel › messages, ChatService › messages(), ChatServicing › messages(), FakeChatService (test), Sample (test)
struct ChatMessage: Decodable, Identifiable {
    // ⮕ KULLANIM [id]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let id: String // mesaj numarası (GUID yazı gelir)
    // ⮕ KULLANIM [text]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let text: String // mesaj metni | balonun içindeki yazı
    // ⮕ KULLANIM [createdAt]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let createdAt: String // gönderilme zamanı, "2026-11-02T14:30:00Z" yazısı | şimdilik göstermiyoruz, ileride saat yazacağız
    // ⮕ KULLANIM [isMine]: okur: ChatView › body
    let isMine: Bool // true = bu mesajı BEN yazdım | NE İŞE YARAR: balonu sağa (benim, renkli) ya da sola (karşı taraf, gri) koymak | backend jetondan bakıp hesaplar
}
