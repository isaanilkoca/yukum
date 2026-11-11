//
//  NotificationServicing.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 12.11.2026.
//

import Foundation


// Bildirim işlemlerinin SÖZLEŞMESİ | ViewModel gerçek servise değil bu sözleşmeye bağlanır → testte sahte servis verilir
// GERÇEK: Models/Services/NotificationService.swift | KULLANAN: ViewModels/NotificationsViewModel (+ HomeViewModel zil sayısı)

protocol NotificationServicing {
    func list(page: Int) async throws -> Page<AppNotification> // GET /notifications?page=
    func unreadCount() async throws -> Int // GET /notifications/unread-count | zil rozeti
    func markRead(id: String) async throws // POST /notifications/{id}/read | 204
    func markAllRead() async throws // POST /notifications/read-all | 204
}
