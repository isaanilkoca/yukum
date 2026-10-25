using System.Net.Mail;
using System.Text.RegularExpressions;
using FluentValidation;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Domain.Accounts;

namespace Yukum.Application.Accounts;

/// <summary>
/// İki kayıt akışının ortak alan kuralları (ad, e-posta, telefon, şifre, KVKK, il). Mesajlar Türkçe ve kullanıcıya
/// gösterilecek biçimdedir. Kurallar yeniden yazılmak yerine buradan çağrılır; iki kayıt ekranı hep aynı davranır.
/// </summary>
internal static partial class AccountRules
{
    // Derleme sırasında üretilen hızlı düzenli ifade: boşluksuz, tek '@', alan adında nokta olmalı.
    [GeneratedRegex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$")]
    private static partial Regex EmailShape();

    /// <summary>Ad-soyad ya da firma adı: dolu, 2–150 karakter.</summary>
    public static IRuleBuilderOptions<T, string?> FullName<T>(this IRuleBuilderInitial<T, string?> rule) =>
        rule.Cascade(CascadeMode.Stop)
            // Cascade(Stop): bir alan için ilk hatada durulur (kullanıcıya tek, anlaşılır mesaj). NotEmpty: boş ya da yalnız boşluk reddedilir.
            .NotEmpty().WithMessage("Ad soyad boş olamaz.")
            .Must(v => v!.Trim().Length >= 2).WithMessage("Ad soyad en az 2 karakter olmalı.")
            .Must(v => v!.Trim().Length <= 150).WithMessage("Ad soyad en fazla 150 karakter olabilir.");

    /// <summary>E-posta: dolu, en çok 254 karakter, geçerli biçim (boşluksuz, tek @, alan adında nokta).</summary>
    public static IRuleBuilderOptions<T, string?> Email<T>(this IRuleBuilderInitial<T, string?> rule) =>
        rule.Cascade(CascadeMode.Stop)
            .NotEmpty().WithMessage("E-posta boş olamaz.")
            .Must(v => v!.Trim().Length <= 254).WithMessage("E-posta en fazla 254 karakter olabilir.")
            // Biçim denetimi: düzenli ifade + .NET MailAddress. Identity'nin kendi denetimiyle ayrışmasın diye ikisi birden.
            .Must(v => IsValidEmail(v!.Trim())).WithMessage("Geçerli bir e-posta adresi girin.");

    /// <summary>Telefon: dolu ve Türkiye cep telefonu biçiminde.</summary>
    public static IRuleBuilderOptions<T, string?> Phone<T>(this IRuleBuilderInitial<T, string?> rule) =>
        rule.Cascade(CascadeMode.Stop)
            .NotEmpty().WithMessage("Telefon numarası boş olamaz.")
            // Telefon +905... biçimine çevrilebiliyorsa geçerlidir.
            .Must(v => PhoneNumberNormalizer.TryNormalize(v, out _))
            .WithMessage("Geçerli bir cep telefonu numarası girin (örn. 0532 123 45 67).");

    /// <summary>Şifre: <see cref="PasswordPolicy"/> kuralları, her ihlal için ayrı Türkçe mesaj.</summary>
    public static IRuleBuilderOptions<T, string?> Password<T>(this IRuleBuilderInitial<T, string?> rule) =>
        rule.Cascade(CascadeMode.Stop)
            .NotEmpty().WithMessage("Şifre boş olamaz.")
            .Must(v => v!.Length >= PasswordPolicy.MinLength).WithMessage($"Şifre en az {PasswordPolicy.MinLength} karakter olmalı.")
            .Must(v => v!.Length <= PasswordPolicy.MaxLength).WithMessage($"Şifre en fazla {PasswordPolicy.MaxLength} karakter olabilir.")
            // Her kural ayrı mesaj verir: kullanıcı tam olarak neyi eksik yaptığını görür.
            .Must(v => PasswordPolicy.HasUppercase(v!)).WithMessage("Şifre en az bir büyük harf içermeli.")
            .Must(v => PasswordPolicy.HasLowercase(v!)).WithMessage("Şifre en az bir küçük harf içermeli.")
            .Must(v => PasswordPolicy.HasDigit(v!)).WithMessage("Şifre en az bir rakam içermeli.");

    /// <summary>KVKK aydınlatma metni onaylanmış olmalı.</summary>
    public static IRuleBuilderOptions<T, bool> KvkkAccepted<T>(this IRuleBuilder<T, bool> rule) =>
        // bool alan true olmalı (KVKK onayı verilmeden kayıt olunamaz).
        rule.Equal(true).WithMessage("Devam etmek için KVKK aydınlatma metnini onaylamanız gerekir.");

    /// <summary>İl: seçilmiş ve veritabanında var olmalı.</summary>
    public static IRuleBuilderOptions<T, int?> ExistingCity<T>(this IRuleBuilderInitial<T, int?> rule, IGeographyRepository geography) =>
        rule.Cascade(CascadeMode.Stop)
            .NotNull().WithMessage("İl seçin.")
            // MustAsync: veritabanı/önbellek gerektiren kural (il listesi önbellekten gelir). 'id!.Value': NotNull'dan geçtiği için dolu.
            .MustAsync((id, cancellationToken) => geography.CityExistsAsync(id!.Value, cancellationToken))
            .WithMessage("Geçerli bir il seçin.");

    // Küçük yardımcı: iki biçim denetimi birlikte.
    private static bool IsValidEmail(string email) =>
        EmailShape().IsMatch(email) && MailAddress.TryCreate(email, out var parsed) && parsed.Address == email;
}

/// <summary>Yük Veren kayıt isteğinin doğrulama kuralları (Türkçe mesajlarla).</summary>
public sealed class RegisterShipperValidator : AbstractValidator<RegisterShipperCommand>
{
    /// <summary>Kuralları kurar. İl kontrolü için il listesine bakılır.</summary>
    public RegisterShipperValidator(IGeographyRepository geography)
    {
        // Ortak kurallar (AccountRules): her alan için tek satır. Kuralların kendisi yukarıda.
        RuleFor(c => c.FullName).FullName();
        RuleFor(c => c.Email).Email();
        RuleFor(c => c.Phone).Phone();
        RuleFor(c => c.Password).Password();
        RuleFor(c => c.KvkkAccepted).KvkkAccepted();
        RuleFor(c => c.CityId).ExistingCity(geography);

        RuleFor(c => c.CompanyName).Must(v => v!.Trim().Length <= 200)
            .When(c => c.CompanyName is not null).WithMessage("Firma adı en fazla 200 karakter olabilir.");
        RuleFor(c => c.TaxOffice).Must(v => v!.Trim().Length <= 100)
            .When(c => c.TaxOffice is not null).WithMessage("Vergi dairesi en fazla 100 karakter olabilir.");
        // Vergi no (VKN) 10, T.C. kimlik no 11 haneli; yalnız rakam.
        // Vergi no (10 hane) ya da T.C. kimlik no (11 hane): yalnız rakam. When(...): yalnız doldurulmuşsa denetlenir (opsiyonel alan).
        RuleFor(c => c.TaxNumber).Must(v => v!.Trim() is { Length: 10 or 11 } t && t.All(char.IsAsciiDigit))
            .When(c => !string.IsNullOrWhiteSpace(c.TaxNumber))
            .WithMessage("Vergi numarası 10 veya 11 haneli rakamlardan oluşmalı.");
    }
}

/// <summary>Taşımacı kayıt isteğinin doğrulama kuralları (Türkçe mesajlarla).</summary>
public sealed class RegisterCarrierValidator : AbstractValidator<RegisterCarrierCommand>
{
    /// <summary>Kuralları kurar. İl kontrolü için il listesine bakılır.</summary>
    public RegisterCarrierValidator(IGeographyRepository geography)
    {
        RuleFor(c => c.FullName).FullName();
        RuleFor(c => c.Email).Email();
        RuleFor(c => c.Phone).Phone();
        RuleFor(c => c.Password).Password();
        RuleFor(c => c.KvkkAccepted).KvkkAccepted();
        RuleFor(c => c.HomeCityId).ExistingCity(geography);

        // Çalışma illeri opsiyoneldir; verilmişse her biri geçerli, hiçbiri tekrarlı olmamalı.
        // RuleForEach: listedeki HER eleman için ayrı denetim; hata 'ServiceCityIds[1]' gibi dizinle bildirilir.
        RuleForEach(c => c.ServiceCityIds)
            .MustAsync((id, cancellationToken) => geography.CityExistsAsync(id, cancellationToken))
            .WithMessage("Geçersiz il seçimi.");
        // Aynı il iki kez seçilmemiş mi? (benzersiz eleman sayısı = liste uzunluğu)
        RuleFor(c => c.ServiceCityIds).Must(ids => ids!.Distinct().Count() == ids!.Count)
            .When(c => c.ServiceCityIds is not null).WithMessage("Aynı il birden fazla seçilmiş.");

        // En az bir araç zorunlu (rapor 6.1); her aracın kendi kuralları vardır.
        // En az 1, en çok 20 araç.
        RuleFor(c => c.Vehicles).Cascade(CascadeMode.Stop)
            .NotEmpty().WithMessage("En az bir araç eklemelisiniz.")
            .Must(v => v!.Count <= 20).WithMessage("En fazla 20 araç eklenebilir.");
        // Her araç için ayrı doğrulayıcı çalışır (aşağıda): hata 'Vehicles[1].CapacityKg' gibi, hangi araçta olduğu belli olur.
        RuleForEach(c => c.Vehicles).SetValidator(new VehicleInputValidator());
    }
}

/// <summary>Taşımacı kaydındaki tek bir aracın doğrulama kuralları.</summary>
public sealed class VehicleInputValidator : AbstractValidator<VehicleInput>
{
    /// <summary>Araç tipi, kapasite, plaka ve hacim kurallarını kurar.</summary>
    public VehicleInputValidator()
    {
        RuleFor(v => v.Type).Cascade(CascadeMode.Stop)
            .NotNull().WithMessage("Araç tipi seçin.")
            // Tanımlı bir araç tipi mi? (Truck, Lorry, Pickup, Refrigerated, Other)
            .Must(t => Enum.IsDefined(t!.Value)).WithMessage("Geçerli bir araç tipi seçin.");

        RuleFor(v => v.CapacityKg).Cascade(CascadeMode.Stop)
            .NotNull().WithMessage("Taşıma kapasitesi girin.")
            // Kapasite 0'dan büyük ve 100.000 kg'dan küçük olmalı (mantıksız değerleri keser).
            .Must(k => k > 0).WithMessage("Taşıma kapasitesi 0'dan büyük olmalı.")
            .Must(k => k <= 100_000).WithMessage("Taşıma kapasitesi en fazla 100.000 kg olabilir.");

        RuleFor(v => v.PlateNumber).Must(p => p!.Trim().Length <= 20)
            .When(v => v.PlateNumber is not null).WithMessage("Plaka en fazla 20 karakter olabilir.");

        RuleFor(v => v.CapacityVolume).Cascade(CascadeMode.Stop)
            .Must(h => h > 0).WithMessage("Hacim 0'dan büyük olmalı.")
            .Must(h => h <= 200).WithMessage("Hacim en fazla 200 m³ olabilir.")
            // Hacim opsiyoneldir; verilmişse 0 ile 200 m³ arasında olmalı.
            .When(v => v.CapacityVolume is not null);
    }
}
