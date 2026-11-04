//
//  SessionRestoring.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: SessionRestoring (sözleşme) ─────────────────────────────────
// │ GERÇEK    : Networking/AuthSession (actor) | SAHTE (test): YukumTests/Support/FakeSession.swift
// │ KULLANAN  : ViewModels/LoginViewModel.restoreSession() → uygulama açılınca otomatik giriş
// └──────────────────────────────────────────────────────────────────────

// SessionRestoring: "kayıtlı oturum varsa kullanıcıyı geri getir" (otomatik giriş) | gerçeği AuthSession actor'u, testte sahtesi verilir
protocol SessionRestoring { // protocol [SWIFT]: sözleşme: "bu fonksiyonlara sahip olan her şey bu sözleşmeyi karşılar"
    func restore() async throws -> LoginUser? // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
}

// SessionSigningOut: "oturumu kapat" (çıkış) | gerçeği AuthSession actor'u, testte sahtesi verilir | kullanan: ViewModels/HomeViewModel.signOut()
protocol SessionSigningOut {
    func signOut() async
}
