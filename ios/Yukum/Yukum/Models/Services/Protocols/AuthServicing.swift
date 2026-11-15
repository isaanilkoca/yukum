//
//  AuthServicing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: AuthServicing (sözleşme) ────────────────────────────────────
// │ GERÇEK    : Models/Services/AuthService.swift | SAHTE (test): YukumTests/Support/FakeAuthService.swift
// │ KULLANAN  : ViewModels/LoginViewModel (login) | RegisterViewModel (register) | CarrierRegisterViewModel (registerCarrier)
// └──────────────────────────────────────────────────────────────────────

// ⮕ KULLANIM [AuthServicing]: kullanır: CarrierRegisterViewModel › auth, CarrierRegisterViewModel › init(), LoginViewModel › auth, LoginViewModel › init(), RegisterViewModel › auth, RegisterViewModel › init() … +2
protocol AuthServicing { // protocol [SWIFT]: sözleşme: "bu fonksiyonlara sahip olan her şey bu sözleşmeyi karşılar"
    // ⮕ KULLANIM [register]: çağırır: RegisterViewModel › register()
    func register(_ body: RegisterRequest) async throws -> RegisterResponse // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
    // ⮕ KULLANIM [registerCarrier]: çağırır: CarrierRegisterViewModel › register()
    func registerCarrier(_ body: RegisterCarrierRequest) async throws -> RegisterResponse
    // ⮕ KULLANIM [login]: çağırır: LoginViewModel › login()
    func login(_ body: LoginRequest) async throws -> LoginResponse
    // 15 Kasım: e-posta doğrulama + şifremi unuttum (gönder uçları her zaman başarılı: e-postanın kayıtlı olup olmadığı söylenmez)
    func sendVerificationCode(_ body: CodeRequest) async throws
    func verifyEmail(_ body: VerifyEmailRequest) async throws
    func forgotPassword(_ body: CodeRequest) async throws
    func resetPassword(_ body: ResetPasswordRequest) async throws
}
