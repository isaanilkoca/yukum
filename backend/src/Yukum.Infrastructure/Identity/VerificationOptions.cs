namespace Yukum.Infrastructure.Identity;

/// <summary>"Auth" ayar bölümü (15 Kasım). Varsayılan güvenli: doğrulanmamış e-postayla giriş YOK.</summary>
public sealed class VerificationOptions
{
    /// <summary>Doğrulanmamış hesap giriş yapabilir mi? Yalnız entegrasyon testleri false yapar (YukumApiFactory): yüzlerce test kayıt+giriş yapar, kod adımını yalnız doğrulama testleri sınar.</summary>
    public bool RequireVerifiedEmail { get; set; } = true;
}
