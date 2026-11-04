//
//  AuthServicing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: AuthServicing (sözleşme) ────────────────────────────────────
// │ GERÇEK    : Services/AuthService.swift | SAHTE (test): YukumTests/Support/FakeAuthService.swift
// │ KULLANAN  : ViewModels/LoginViewModel (login) | RegisterViewModel (register) | CarrierRegisterViewModel (registerCarrier)
// │ HAZIR (Swift/Apple) [SWIFT] : async, throws, protocol
// │ BİZİM (bizim yazdığımız) [BİZİM] : türler: AuthServicing | fonksiyonlar: register, registerCarrier, login
// └──────────────────────────────────────────────────────────────────────

protocol AuthServicing { // protocol [SWIFT]: sözleşme: "bu fonksiyonlara sahip olan her şey bu sözleşmeyi karşılar"
    func register(_ body: RegisterRequest) async throws -> RegisterResponse // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
    func registerCarrier(_ body: RegisterCarrierRequest) async throws -> RegisterResponse
    func login(_ body: LoginRequest) async throws -> LoginResponse
}
