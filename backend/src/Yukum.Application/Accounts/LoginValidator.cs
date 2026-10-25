using FluentValidation;

namespace Yukum.Application.Accounts;

/// <summary>
/// Giriş isteğinin doğrulama kuralları (Türkçe mesajlarla). Yalnız "alan dolu mu, makul uzunlukta mı" bakılır;
/// şifre karmaşıklığı burada denetlenmez (kayıt kuralı sonradan değişse bile eski kullanıcı girebilsin).
/// Kimlik bilgisinin doğruluğu ayrı kontrol edilir.
/// </summary>
public sealed class LoginValidator : AbstractValidator<LoginCommand>
{
    /// <summary>Kuralları kurar.</summary>
    public LoginValidator()
    {
        // E-posta/telefon: dolu ve en çok 254 karakter.
        RuleFor(c => c.EmailOrPhone).Cascade(CascadeMode.Stop)
            .NotEmpty().WithMessage("E-posta veya telefon boş olamaz.")
            .Must(v => v!.Trim().Length <= 254).WithMessage("E-posta veya telefon en fazla 254 karakter olabilir.");

        // Üst sınır, aşırı uzun şifreyle hash'leme maliyetini şişirmeyi (hizmeti yavaşlatma) önler.
        // Şifre: dolu ve en çok 128 karakter. Karmaşıklık burada denetlenmez.
        RuleFor(c => c.Password).Cascade(CascadeMode.Stop)
            .NotEmpty().WithMessage("Şifre boş olamaz.")
            .Must(v => v!.Length <= PasswordPolicy.MaxLength).WithMessage($"Şifre en fazla {PasswordPolicy.MaxLength} karakter olabilir.");

        // Cihaz kimliği zorunlu (oturum jetonları cihaz bazlı yönetilecek, D4).
        RuleFor(c => c.DeviceId).Cascade(CascadeMode.Stop)
            .NotEmpty().WithMessage("Cihaz kimliği boş olamaz.")
            .Must(v => v!.Trim().Length <= 100).WithMessage("Cihaz kimliği en fazla 100 karakter olabilir.");

        // Cihaz adı opsiyonel; verilmişse en çok 100 karakter.
        RuleFor(c => c.DeviceName)
            .Must(v => v!.Trim().Length <= 100).When(c => c.DeviceName is not null)
            .WithMessage("Cihaz adı en fazla 100 karakter olabilir.");
    }
}
