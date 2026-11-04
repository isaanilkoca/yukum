//
//  SendMessageRequest.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: SendMessageRequest (mesaj gönderme paketi) ──────────────────
// │ MODEL     : Mesaj göndermek için GİDEN paket: {"text": "..."}
// │ DOLDURAN  : Features/Chat/ChatViewModel.send() (draft'ın baş/son boşluğu temizlenmiş hâli)
// │ YOL       : Features/Chat/ChatView (Gönder) → ChatViewModel.send() → Features/Chat/ChatService.send → POST /api/v1/offers/{id}/messages
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA: sohbet paketlerinin kalıpları. Gönderilecek mesaj + gelen mesaj satırı.
// BAĞLANTI: Features/Chat/ChatService.swift bu kalıpları kullanır | API: GET/POST /api/v1/offers/{offerId}/messages | ekran: Features/Chat/ChatView.swift

// SendMessageRequest: giden paket (yazdığımız mesaj).
// NE İŞE YARAR: POST'un gövdesi, JSON'a çevrilip yollanır {"text":"..."} | Encodable [SWIFT]: struct → JSON
// NEREDE KULLANILIR: Features/Chat/ChatView.swift "Gönder" düğmesi paketi hazırlar → ChatService.send
// ⮕ KULLANIM [SendMessageRequest]: kullanır: ChatViewModel › send(), ChatService › send(), ChatServicing › send(), FakeChatService (test)
struct SendMessageRequest: Encodable {
    // ⮕ KULLANIM [text]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let text: String // mesaj metni | API'deki "text" ile aynı ad olmalı
}
