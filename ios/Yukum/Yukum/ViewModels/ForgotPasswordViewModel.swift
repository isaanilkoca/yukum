//
//  ForgotPasswordViewModel.swift
//  Yukum
//
//  Şifremi unuttum (15 Kasım): 1) e-posta/telefon → kod gönder  2) kod + yeni şifre.
//

import Foundation  // [SWIFT] temel türler
import Observation // [SWIFT] @Observable

// ┌─ BAĞLANTI HARİTASI: ForgotPasswordViewModel ──────────────────────────────────
// │ EKRAN   : Views/ForgotPasswordView ← LoginView "Şifremi unuttum" (e-posta/telefon ve rol giriş ekranından dolu gelir)
// │ SERVİS  : AuthServicing.forgotPassword → POST /auth/password/forgot (her zaman başarılı: kayıtlı mı söylenmez)
// │           AuthServicing.resetPassword  → POST /auth/password/reset (şifre değişir, tüm cihazlarda oturum kapanır)
// │ KURAL   : yeni şifre kayıttaki kuralla aynı (8+, büyük+küçük harf+rakam) — asıl denetim sunucuda (PasswordPolicy)
// └──────────────────────────────────────────────────────────────────────
@MainActor
@Observable
final class ForgotPasswordViewModel {
    enum Step { case request, reset } // hangi adımdayız: kod iste / kod + yeni şifre

    private let auth: AuthServicing
    init(emailOrPhone: String, role: LoginRole, auth: AuthServicing = AuthService()) {
        self.emailOrPhone = emailOrPhone
        self.role = role
        self.auth = auth
    }

    var step: Step = .request
    var emailOrPhone: String
    var role: LoginRole
    var code = "" { didSet { if code.count > 6 || code.contains(where: { !$0.isNumber }) { code = String(code.filter(\.isNumber).prefix(6)) } } }
    var newPassword = ""
    var confirmPassword = ""
    var errorMessage: String?
    var isLoading = false

    private var identity: String { emailOrPhone.trimmingCharacters(in: .whitespaces) }

    // 1. adım: kod iste | başarıda 2. adıma geçer (e-posta kayıtlı olmasa da: sunucu söylemez, kullanıcı "kod gelmedi" görür)
    func sendCode() async {
        guard !identity.isEmpty else { errorMessage = "E-posta ya da telefonunu yaz."; return }
        isLoading = true; defer { isLoading = false }
        errorMessage = nil
        do {
            try await auth.forgotPassword(CodeRequest(emailOrPhone: identity, role: role.rawValue))
            step = .reset
        } catch { errorMessage = error.userMessage ?? "Kod gönderilemedi." }
    }

    // 2. adım: kod + yeni şifre | -> Bool: değişti mi (ekran kapanır, giriş ekranında şifre alanı yeni şifreyle dolu gelmez: kullanıcı yazar)
    func reset() async -> Bool {
        guard code.count == 6 else { errorMessage = "E-postana gelen 6 haneli kodu gir."; return false }
        guard !newPassword.isEmpty else { errorMessage = "Yeni şifreni yaz."; return false }
        guard newPassword == confirmPassword else { errorMessage = "Şifreler aynı değil."; return false }
        isLoading = true; defer { isLoading = false }
        errorMessage = nil
        do {
            try await auth.resetPassword(ResetPasswordRequest(emailOrPhone: identity, role: role.rawValue, code: code, newPassword: newPassword))
            newPassword = ""; confirmPassword = "" // şifre bellekte kalmasın
            return true
        } catch {
            errorMessage = error.userMessage ?? "Şifre değiştirilemedi."
            return false
        }
    }
}
