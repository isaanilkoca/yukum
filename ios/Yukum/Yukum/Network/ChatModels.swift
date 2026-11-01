//
//  ChatModels.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 2.11.2026.
//

import Foundation


// BU DOSYA: sohbet paketlerinin kalıpları. Gönderilecek mesaj + gelen mesaj satırı.
// BAĞLANTI: Network/ChatService.swift bu kalıpları kullanır | API: GET/POST /api/v1/offers/{offerId}/messages | ekran: View/ChatView.swift

// SendMessageRequest: giden paket (yazdığımız mesaj).
// NE İŞE YARAR: POST'un gövdesi, JSON'a çevrilip yollanır {"text":"..."} | Encodable [SWIFT]: struct → JSON
// NEREDE KULLANILIR: View/ChatView.swift "Gönder" düğmesi paketi hazırlar → ChatService.send
struct SendMessageRequest: Encodable {
    let text: String // mesaj metni | API'deki "text" ile aynı ad olmalı
}

// ChatMessage: sohbetteki TEK MESAJIN kalıbı (GET listesindeki her eleman).
// NE İŞE YARAR: API'den gelen JSON her mesaj için bu struct'a çevrilir | Decodable [SWIFT]: JSON → struct | Identifiable: benzersiz id'si var, List/ForEach'te id: yazmak gerekmez
// NEREDE KULLANILIR: ChatService.messages() bu struct'ın listesini döner → View/ChatView.swift balonları çizer
struct ChatMessage: Decodable, Identifiable {
    let id: String // mesaj numarası (GUID yazı gelir)
    let text: String // mesaj metni | balonun içindeki yazı
    let createdAt: String // gönderilme zamanı, "2026-11-02T14:30:00Z" yazısı | şimdilik göstermiyoruz, ileride saat yazacağız
    let isMine: Bool // true = bu mesajı BEN yazdım | NE İŞE YARAR: balonu sağa (benim, renkli) ya da sola (karşı taraf, gri) koymak | backend jetondan bakıp hesaplar
}
