//
//  Notification+SessionExpired.swift
//  Yukum
//

import Foundation

// "Oturum süresi doldu, yeniden giriş gerekiyor" haberi | HomeView dinler ve giriş ekranına döner
extension Notification.Name {
    nonisolated static let sessionExpired = Notification.Name("yukum.sessionExpired") // NotificationCenter [SWIFT]: uygulama içi anons panosu | biri "yayınlar", ilgilenen ekranlar "dinler"
}
