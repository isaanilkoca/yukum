using FluentValidation;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Messaging;

namespace Yukum.Application.Accounts;

/// <summary>Yük Veren kaydını işler: doğrular, e-posta ve telefonu normalleştirir, hesabı oluşturur.</summary>
public sealed class RegisterShipperHandler(IValidator<RegisterShipperCommand> validator, IAccountService accounts, IVerificationService verification)
    : ICommandHandler<RegisterShipperCommand, RegisteredUserDto>
{
    /// <summary>Geçersizse <see cref="ValidationException"/>, e-posta/telefon kayıtlıysa <see cref="Common.ConflictException"/> fırlatır.</summary>
    public async Task<RegisteredUserDto> HandleAsync(RegisterShipperCommand command, CancellationToken cancellationToken = default)
    {
        // 1) Doğrula: Türkçe mesajlı kurallar (RegisterValidators.cs). Geçersizse ValidationException fırlar → 400; aşağıya hiç inilmez.
        await validator.ValidateAndThrowAsync(command, cancellationToken);

        // 2) Normalleştir. 'with': komutun KOPYASINI al, yalnız yazılan alanları değiştir (record'lar değişmezdir, orijinal bozulmaz).
        var normalized = command with
        {
            // Baş/son boşluk atılır. '!': doğrulama geçtiği için boş olmadığını biliyoruz.
            FullName = command.FullName!.Trim(),
            // E-posta: kırp + küçük harf.
            Email = AccountNormalization.Email(command.Email!),
            // Telefon: +905XXXXXXXXX biçimi.
            Phone = AccountNormalization.Phone(command.Phone!),
            // Opsiyonel metinler: kırp, boş kalıyorsa null yap.
            CompanyName = AccountNormalization.OptionalText(command.CompanyName),
            TaxNumber = AccountNormalization.OptionalText(command.TaxNumber),
            TaxOffice = AccountNormalization.OptionalText(command.TaxOffice)
        };
        // 3) Hesabı oluştur (Infrastructure/AccountService.cs): kullanıcı + rol + profil TEK işlemde. E-posta/telefon kayıtlıysa ConflictException → 409.
        var created = await accounts.RegisterShipperAsync(normalized, cancellationToken);
        // 4) 15 Kasım: e-posta doğrulama kodu gönderilir (iOS kayıttan sonra kod ekranına geçer) ⮕ VerificationContracts.cs
        await verification.SendCodeAsync(normalized.Email!, Yukum.Domain.Accounts.UserType.Shipper, Yukum.Domain.Accounts.VerificationPurpose.EmailVerification, cancellationToken);
        return created;
    }
}

/// <summary>Taşımacı kaydını işler: doğrular, e-posta ve telefonu normalleştirir, hesabı oluşturur.</summary>
public sealed class RegisterCarrierHandler(IValidator<RegisterCarrierCommand> validator, IAccountService accounts, IVerificationService verification)
    : ICommandHandler<RegisterCarrierCommand, RegisteredUserDto>
{
    /// <summary>Geçersizse <see cref="ValidationException"/>, e-posta/telefon kayıtlıysa <see cref="Common.ConflictException"/> fırlatır.</summary>
    public async Task<RegisteredUserDto> HandleAsync(RegisterCarrierCommand command, CancellationToken cancellationToken = default)
    {
        // 1) Doğrula (RegisterValidators.cs → RegisterCarrierValidator): araç, il, şifre... Geçersizse → 400.
        await validator.ValidateAndThrowAsync(command, cancellationToken);

        // 2) Normalleştir: e-posta, telefon, plaka tek biçime çevrilir (aynı kişi iki farklı yazılışla ikinci hesap açamasın).
        var normalized = command with
        {
            FullName = command.FullName!.Trim(),
            Email = AccountNormalization.Email(command.Email!),
            Phone = AccountNormalization.Phone(command.Phone!),
            // Her aracın plakası kırpılır; boşsa null olur.
            Vehicles = (command.Vehicles ?? []).Select(v => v with { PlateNumber = AccountNormalization.OptionalText(v.PlateNumber) }).ToList() // araçsız kayıt: boş liste
        };
        // 3) Hesabı oluştur: kullanıcı + rol + profil + araçlar + çalışma illeri TEK işlemde (biri düşerse hiçbiri kaydedilmez).
        var created = await accounts.RegisterCarrierAsync(normalized, cancellationToken);
        // 4) 15 Kasım: e-posta doğrulama kodu ⮕ VerificationContracts.cs
        await verification.SendCodeAsync(normalized.Email!, Yukum.Domain.Accounts.UserType.Carrier, Yukum.Domain.Accounts.VerificationPurpose.EmailVerification, cancellationToken);
        return created;
    }
}

/// <summary>Kayıt verisinin tek biçime çevrilmesi: aynı e-posta/telefon farklı yazılışla iki hesap açamasın.</summary>
internal static class AccountNormalization
{
    /// <summary>E-posta: baş/son boşluk atılır, küçük harfe çevrilir.</summary>
    public static string Email(string email) => email.Trim().ToLowerInvariant();

    /// <summary>Telefon: <c>+905XXXXXXXXX</c> biçimi (doğrulamadan geçtiği için her zaman başarılıdır).</summary>
    public static string Phone(string phone) =>
        // Doğrulamadan geçtiği için her zaman başarılıdır; başarısız olursa bu bir programlama hatasıdır (500).
        PhoneNumberNormalizer.TryNormalize(phone, out var normalized)
            ? normalized
            : throw new InvalidOperationException("Doğrulanmış telefon normalleştirilemedi.");

    /// <summary>İsteğe bağlı metin: baş/son boşluk atılır, geriye boş kalıyorsa <c>null</c> olur.</summary>
    public static string? OptionalText(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
