using Yukum.Domain.Common;

namespace Yukum.Domain.Accounts;

/// <summary>
/// E-postaya gönderilen 6 haneli tek kullanımlık kod (15 Kasım: e-posta doğrulama + şifremi unuttum).
/// Kodun KENDİSİ saklanmaz, yalnız özeti (SHA-256): veritabanı sızsa bile kod okunamaz (şifrelerdeki mantığın aynısı).
/// </summary>
// BAĞLANTI HARİTASI: AuthController (/auth/verify-email*, /auth/password/*) → Verification handler'ları → IVerificationService
//   → Infrastructure/Identity/VerificationService ("VerificationCodes" tablosu + IEmailSender)
public class VerificationCode : BaseEntity
{
    /// <summary>Kodun sahibi.</summary>
    public Guid UserId { get; set; }

    /// <summary>Ne için: e-posta doğrulama mı, şifre sıfırlama mı.</summary>
    public VerificationPurpose Purpose { get; set; }

    /// <summary>Kodun SHA-256 özeti (64 onaltılık karakter; kullanıcı numarasıyla tuzlanır).</summary>
    public string CodeHash { get; set; } = "";

    /// <summary>Son geçerlilik anı (UTC).</summary>
    public DateTime ExpiresAt { get; set; }

    /// <summary>Yanlış deneme sayısı; sınıra ulaşınca kod ölür (6 haneyi deneme-yanılmayla bulmayı engeller).</summary>
    public int Attempts { get; set; }

    /// <summary>Doğru girildiği an; doluysa kod bir daha kullanılamaz.</summary>
    public DateTime? UsedAt { get; set; }
}
