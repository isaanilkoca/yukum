using Yukum.Domain.Accounts;

namespace Yukum.Application.Abstractions.Identity;

/// <summary>
/// Tek kullanımlık e-posta kodları: üret + gönder, doğrula, şifre sıfırla. Identity (UserManager) ayrıntısı Infrastructure'da kalır.
/// GÜVENLİK KURALLARI (uygulaması Infrastructure/Identity/VerificationService):
///   kod 6 hane, 15 dk geçerli, 5 yanlış denemede ölür, 60 sn'den sık yeni kod gönderilmez, yeni kod eskisini geçersiz kılar,
///   "bu e-posta kayıtlı mı?" sorusu cevaplanmaz (gönder uçları her zaman başarılı döner).
/// </summary>
public interface IVerificationService
{
    /// <summary>Kod üretir ve hesabın kayıtlı e-postasına gönderir (hesap e-posta ya da telefonla bulunur). Kullanıcı yoksa (ya da doğrulama için zaten doğrulanmışsa) sessizce hiçbir şey yapmaz.</summary>
    Task SendCodeAsync(string emailOrPhone, UserType role, VerificationPurpose purpose, CancellationToken cancellationToken = default);

    /// <summary>E-posta doğrulama kodunu kontrol eder; doğruysa hesap doğrulanır. Yanlış/süresi dolmuşsa ValidationException (400).</summary>
    Task VerifyEmailAsync(string emailOrPhone, UserType role, string code, CancellationToken cancellationToken = default);

    /// <summary>Şifre sıfırlama kodunu kontrol eder; doğruysa şifreyi değiştirir, tüm oturumları kapatır, kilidi açar, e-postayı doğrulanmış sayar.</summary>
    Task ResetPasswordAsync(string emailOrPhone, UserType role, string code, string newPassword, CancellationToken cancellationToken = default);
}
