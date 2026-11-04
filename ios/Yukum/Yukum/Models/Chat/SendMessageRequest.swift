//
//  SendMessageRequest.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: SendMessageRequest (mesaj gönderme paketi) ──────────────────
// │ MODEL     : Mesaj göndermek için GİDEN paket: {"text": "..."}
// │ DOLDURAN  : ViewModels/ChatViewModel.send() (draft'ın baş/son boşluğu temizlenmiş hâli)
// │ YOL       : Views/ChatView (Gönder) → ChatViewModel.send() → Services/ChatService.send → POST /api/v1/offers/{id}/messages
// │ HAZIR (Swift/Apple) [SWIFT] : Encodable, String
// │ BİZİM (bizim yazdığımız) [BİZİM] : türler: SendMessageRequest | değişken/durumlar: text
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA: sohbet paketlerinin kalıpları. Gönderilecek mesaj + gelen mesaj satırı.
// BAĞLANTI: Services/ChatService.swift bu kalıpları kullanır | API: GET/POST /api/v1/offers/{offerId}/messages | ekran: Views/ChatView.swift

// SendMessageRequest: giden paket (yazdığımız mesaj).
// NE İŞE YARAR: POST'un gövdesi, JSON'a çevrilip yollanır {"text":"..."} | Encodable [SWIFT]: struct → JSON
// NEREDE KULLANILIR: Views/ChatView.swift "Gönder" düğmesi paketi hazırlar → ChatService.send
struct SendMessageRequest: Encodable {
    let text: String // mesaj metni | API'deki "text" ile aynı ad olmalı
}
