//
//  NotificationService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 12.11.2026.
//

import Foundation

// Bildirim uçlarıyla konuşur. İsteğin kendisi (jeton, 401'de yenileme, hata çevirme) APIClient'ta; burada yalnız "hangi adres, ne döner" yazılır
// ÇAĞIRAN: ViewModels/NotificationsViewModel, HomeViewModel (zil sayısı) — NotificationServicing sözleşmesi üzerinden | API: backend NotificationsController

struct NotificationService {
    private let api = APIClient.shared // tüm istekleri bu kapıdan geçer
    
    // list: bildirimlerin BİR SAYFASI (en yeni üstte) | URLQueryItem [SWIFT]: adresin ?'ten sonraki "ad=değer" çifti | String(Int): sayıdan yazı
    
    func list(page: Int) async throws -> Page<AppNotification> {
          let items = [URLQueryItem(name: "page", value: String(page)),
                       URLQueryItem(name: "pageSize", value: String(Self.pageSize))]
          return try await api.send(.get, "/api/v1/notifications", query: items, fallback: "Bildirimler yüklenemedi.")
      }
    
    // unreadCount: zil rozetindeki sayı | cevap {"count": n}, yalnız n döndürülür
      func unreadCount() async throws -> Int {
          let result: NotificationCount = try await api.send(.get, "/api/v1/notifications/unread-count", fallback: "Bildirim sayısı alınamadı.")
          return result.count
      }
    
    
    // markRead / markAllRead: gövdesiz POST, cevap 204 (sendNoContent) | sunucu iki işlemde de idempotent (tekrar çağrılabilir)
    func markRead(id: String) async throws {
        try await api.sendNoContent(.post, "/api/v1/notifications/\(id)/read", fallback: "Bildirim güncellenemedi.")
    }

    func markAllRead() async throws {
        try await api.sendNoContent(.post, "/api/v1/notifications/read-all", fallback: "Bildirimler güncellenemedi.")
    }

    static let pageSize = 20 // static [SWIFT]: türe ait sabit | API en çok 50 kabul eder
}

// ListingService'teki kalıp: "sen de bu sözleşmeyi karşılıyorsun" demek için boş extension yeter
extension NotificationService: NotificationServicing {}
