//
//  Notification+SessionExpired.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: .sessionExpired bildirimi ───────────────────────────────────
// │ YAYINLAYAN: Networking/AuthSession.expireSession() (yenileme reddedilince)
// │ DİNLEYEN  : Views/HomeView → .onReceive(NotificationCenter...publisher(for: .sessionExpired)) { dismiss() } → giriş ekranına dönülür
// └──────────────────────────────────────────────────────────────────────

// "Oturum süresi doldu, yeniden giriş gerekiyor" haberi | HomeView dinler ve giriş ekranına döner
extension Notification.Name {
    nonisolated static let sessionExpired = Notification.Name("yukum.sessionExpired") // NotificationCenter [SWIFT]: uygulama içi anons panosu | biri "yayınlar", ilgilenen ekranlar "dinler"
}
