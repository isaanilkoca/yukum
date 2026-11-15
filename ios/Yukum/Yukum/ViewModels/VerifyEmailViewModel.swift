//
//  VerifyEmailViewModel.swift
//  Yukum
//
//  E-posta doğrulama kodu ekranının mantığı (15 Kasım; kullanıcı kararı: doğrulamadan giriş YOK).
//

import Foundation  // [SWIFT] temel türler
import Observation // [SWIFT] @Observable

// ┌─ BAĞLANTI HARİTASI: VerifyEmailViewModel ─────────────────────────────────────
// │ EKRAN   : Views/VerifyEmailView ← LoginView .sheet(item: LoginViewModel.verifyTarget)
// │ AÇILIŞ  : (1) kayıt bitti → RoleSelectionView.onDone → verifyTarget (loginAfter: false)
// │           (2) girişte 403 "email_not_verified" → LoginViewModel.login catch → verifyTarget (loginAfter: true)
// │ SERVİS  : AuthServicing.verifyEmail → POST /auth/verify-email | sendVerificationCode → POST /auth/verify-email/send
// │ KURAL   : 6 rakam (sunucu da denetler) · yeniden gönder 60 sn'de bir (sunucu da 60 sn'den sık göndermez)
// └──────────────────────────────────────────────────────────────────────
@MainActor
@Observable
final class VerifyEmailViewModel {
    let target: VerifyTarget
    private let auth: AuthServicing
    private let now: () -> Date // saat: gerçekte Date(), testte sabit | NEDEN: geri sayımı beklemeden test edebilmek
    static let cooldown: TimeInterval = 60

    init(target: VerifyTarget, auth: AuthServicing = AuthService(), now: @escaping () -> Date = { Date() }) {
        self.target = target
        self.auth = auth
        self.now = now
        // Ekran açıldığında kod ZATEN gönderilmiş sayılır (kayıtta sunucu gönderdi / girişte daha önce gitti) → ilk 60 sn yeniden gönder kilitli
        self.resendAvailableAt = now().addingTimeInterval(Self.cooldown)
    }

    var code = "" { didSet { if code.count > 6 || code.contains(where: { !$0.isNumber }) { code = String(code.filter(\.isNumber).prefix(6)) } } } // didSet [SWIFT]: değer değişince çalışır → yalnız rakam, en çok 6
    var errorMessage: String?
    var infoMessage: String?
    var isLoading = false
    var resendAvailableAt: Date

    // Kalan saniye (0 → düğme açık) | View bunu TimelineView ile her saniye yeniden okur
    func secondsLeft(at date: Date? = nil) -> Int { max(0, Int((resendAvailableAt.timeIntervalSince(date ?? now())).rounded(.up))) }

    // -> Bool: doğrulandı mı (ekran kapanır, LoginView devam eder)
    func verify() async -> Bool {
        guard code.count == 6 else { errorMessage = "E-postana gelen 6 haneli kodu gir."; return false }
        isLoading = true; defer { isLoading = false }
        errorMessage = nil
        do {
            try await auth.verifyEmail(VerifyEmailRequest(emailOrPhone: target.emailOrPhone, role: target.role.rawValue, code: code))
            return true
        } catch {
            errorMessage = error.userMessage ?? "Kod doğrulanamadı."
            return false
        }
    }

    func resend() async {
        guard secondsLeft() == 0 else { return }
        errorMessage = nil
        do {
            try await auth.sendVerificationCode(CodeRequest(emailOrPhone: target.emailOrPhone, role: target.role.rawValue))
            resendAvailableAt = now().addingTimeInterval(Self.cooldown)
            code = ""
            infoMessage = "Yeni kod gönderildi. Gelen kutunu (ve gereksiz klasörünü) kontrol et."
        } catch {
            errorMessage = error.userMessage ?? "Kod gönderilemedi."
        }
    }
}
