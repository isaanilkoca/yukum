//
//  SendMessageRequest.swift
//  Yukum
//

import Foundation

// BU DOSYA: sohbet paketlerinin kalıpları. Gönderilecek mesaj + gelen mesaj satırı.
// BAĞLANTI: Services/ChatService.swift bu kalıpları kullanır | API: GET/POST /api/v1/offers/{offerId}/messages | ekran: Views/ChatView.swift

// SendMessageRequest: giden paket (yazdığımız mesaj).
// NE İŞE YARAR: POST'un gövdesi, JSON'a çevrilip yollanır {"text":"..."} | Encodable [SWIFT]: struct → JSON
// NEREDE KULLANILIR: Views/ChatView.swift "Gönder" düğmesi paketi hazırlar → ChatService.send
struct SendMessageRequest: Encodable {
    let text: String // mesaj metni | API'deki "text" ile aynı ad olmalı
}
