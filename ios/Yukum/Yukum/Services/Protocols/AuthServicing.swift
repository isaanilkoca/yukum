//
//  AuthServicing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: AuthServicing (sözleşme) ────────────────────────────────────
// │ GERÇEK    : Services/AuthService.swift | SAHTE (test): YukumTests/Support/FakeAuthService.swift
// │ KULLANAN  : ViewModels/LoginViewModel (login) | RegisterViewModel (register) | CarrierRegisterViewModel (registerCarrier)
// └──────────────────────────────────────────────────────────────────────

protocol AuthServicing {
    func register(_ body: RegisterRequest) async throws -> RegisterResponse
    func registerCarrier(_ body: RegisterCarrierRequest) async throws -> RegisterResponse
    func login(_ body: LoginRequest) async throws -> LoginResponse
}
