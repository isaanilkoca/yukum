namespace Yukum.Application.Accounts;

// ┌─ E-POSTA DOĞRULAMA + ŞİFREMİ UNUTTUM (15 Kasım; kullanıcı kararı: doğrulamadan giriş YOK) ───────────────────────────────
// │ BAĞLANTI HARİTASI (hepsi anonim, "auth" hız sınırı)
// │   POST /api/v1/auth/verify-email/send   {emailOrPhone, role}                   → SendVerificationCodeHandler → IVerificationService.SendCodeAsync
// │   POST /api/v1/auth/verify-email        {emailOrPhone, role, code}             → VerifyEmailHandler          → VerifyEmailAsync
// │   POST /api/v1/auth/password/forgot     {emailOrPhone, role}                   → ForgotPasswordHandler       → SendCodeAsync(PasswordReset)
// │   POST /api/v1/auth/password/reset      {emailOrPhone, role, code, newPassword}→ ResetPasswordHandler        → ResetPasswordAsync
// │ ZİNCİR: kayıt (RegisterHandlers) → kod e-postası → iOS kod ekranı → verify-email → giriş
// │         doğrulanmamış hesapla giriş → 403 + code "email_not_verified" (AuthService) → iOS kod ekranını açar
// │ NEDEN emailOrPhone: girişteki gibi telefonla giren de kullanabilsin; kod her zaman hesabın KAYITLI e-postasına gider.
// │ NEDEN role: aynı e-posta iki rolde ayrı hesap olabilir (K-022); kod hangi hesaba ait, rol söyler.
// └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/// <summary>Komut: e-posta doğrulama kodunu (yeniden) gönder.</summary>
public sealed record SendVerificationCodeCommand(string? EmailOrPhone, string? Role);

/// <summary>Komut: e-posta doğrulama kodunu gir.</summary>
public sealed record VerifyEmailCommand(string? EmailOrPhone, string? Role, string? Code);

/// <summary>Komut: şifremi unuttum, kod gönder.</summary>
public sealed record ForgotPasswordCommand(string? EmailOrPhone, string? Role);

/// <summary>Komut: kod + yeni şifre.</summary>
public sealed record ResetPasswordCommand(string? EmailOrPhone, string? Role, string? Code, string? NewPassword);
