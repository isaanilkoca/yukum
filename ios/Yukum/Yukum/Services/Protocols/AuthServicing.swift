//
//  AuthServicing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: AuthServicing (sözleşme) ────────────────────────────────────
// │ GERÇEK    : Services/AuthService.swift | SAHTE (test): YukumTests/Support/FakeAuthService.swift
// │ KULLANAN  : ViewModels/LoginViewModel (login)
// └──────────────────────────────────────────────────────────────────────

protocol AuthServicing {
    func login(_ body: LoginRequest) async throws -> LoginResponse
}
