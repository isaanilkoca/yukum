//
//  AppNotification.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 12.11.2026.
//

import Foundation


// Listedeki bir bildirim | API: GET /api/v1/notifications → Page<AppNotification>
// NEDEN "AppNotification": Foundation'da zaten "Notification" türü var (NotificationCenter), aynı ad karışırdı
// Identifiable [SWIFT]: "her elemanın benzersiz id'si var" sözü | List/ForEach satırları bu id ile ayırt eder (id alanı yeter, ek kod gerekmez)
// BAĞLANTI: NotificationService.list döner → NotificationsViewModel.items saklar → Views/NotificationsView satırları çizer

struct AppNotification: Decodable, Identifiable {
    let id: String
    let type: String // "OfferReceived", "OfferAccepted"... sunucudan yazı gelir | bilinmeyen yeni tür gelirse çökmesin diye enum yapmadık
    let title: String // "Yeni teklif"
    let body: String // "“Un çuvalları” ilanı için 1.200 ₺ teklif geldi."
    let listingId: String? // String?: nil olabilir | ilgili ilan (dokununca gidilecek yer)
    let offerId: String? // ilgili teklif
    var isRead: Bool // var: tek değişebilen alan | satıra basınca ekranda hemen "okundu" gösterilir (iyimser güncelleme)
    let createdAt: String // "2026-11-11T21:00:00Z" yazısı | saat gösterimi Views tarafında
}


// NotificationCount: {"count": 3} cevabının kalıbı | NotificationService.unreadCount() bunu çevirip yalnız sayıyı döner
struct NotificationCount: Decodable {
    let count: Int
}
