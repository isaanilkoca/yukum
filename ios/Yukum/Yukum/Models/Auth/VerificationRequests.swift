//
//  VerificationRequests.swift
//  Yukum
//
//  E-posta doğrulama + şifremi unuttum istek paketleri (15 Kasım).
//

import Foundation // [SWIFT] temel türler

// ┌─ BAĞLANTI HARİTASI: Verification istekleri ───────────────────────────────────
// │ CodeRequest          → AuthService.sendVerificationCode / forgotPassword → POST /auth/verify-email/send | /auth/password/forgot
// │ VerifyEmailRequest   → AuthService.verifyEmail   → POST /auth/verify-email
// │ ResetPasswordRequest → AuthService.resetPassword → POST /auth/password/reset
// │ emailOrPhone: girişteki gibi e-posta YA DA telefon; kod her zaman hesabın kayıtlı E-POSTASINA gider (backend VerificationService)
// │ role: aynı e-posta iki rolde ayrı hesap olabilir → LoginRole.rawValue ("Shipper"/"Carrier")
// └──────────────────────────────────────────────────────────────────────

struct CodeRequest: Encodable {
    let emailOrPhone: String
    let role: String
}

struct VerifyEmailRequest: Encodable {
    let emailOrPhone: String
    let role: String
    let code: String
}

struct ResetPasswordRequest: Encodable {
    let emailOrPhone: String
    let role: String
    let code: String
    let newPassword: String
}

// Kod ekranının açılış bilgisi | Identifiable [SWIFT]: .sheet(item:) dolunca açar, nil olunca kapatır
// loginAfter: doğrulanınca otomatik giriş yapılsın mı (girişten geldiyse şifre elde → evet; kayıttan geldiyse şifre yok → hayır)
// ⮕ KULLANIM [VerifyTarget]: LoginViewModel.verifyTarget → LoginView .sheet → VerifyEmailView
struct VerifyTarget: Identifiable {
    let emailOrPhone: String
    let role: LoginRole
    let loginAfter: Bool
    var id: String { emailOrPhone + role.rawValue }
}
