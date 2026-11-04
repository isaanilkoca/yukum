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
protocol SessionRestoring {
    func restore() async throws -> LoginUser?
}

// SessionSigningOut: "oturumu kapat" (çıkış) | gerçeği AuthSession actor'u, testte sahtesi verilir | kullanan: ViewModels/HomeViewModel.signOut()
protocol SessionSigningOut {
    func signOut() async
}
