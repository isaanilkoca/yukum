using FluentValidation;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Messaging;

namespace Yukum.Application.Accounts;

/// <summary>Yük Veren kaydını işler: doğrular, e-posta ve telefonu normalleştirir, hesabı oluşturur.</summary>
public sealed class RegisterShipperHandler(IValidator<RegisterShipperCommand> validator, IAccountService accounts)
    : ICommandHandler<RegisterShipperCommand, RegisteredUserDto>
{
    /// <summary>Geçersizse <see cref="ValidationException"/>, e-posta/telefon kayıtlıysa <see cref="Common.ConflictException"/> fırlatır.</summary>
    public async Task<RegisteredUserDto> HandleAsync(RegisterShipperCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);

        var normalized = command with
        {
            FullName = command.FullName!.Trim(),
            Email = AccountNormalization.Email(command.Email!),
            Phone = AccountNormalization.Phone(command.Phone!),
            CompanyName = AccountNormalization.OptionalText(command.CompanyName),
            TaxNumber = AccountNormalization.OptionalText(command.TaxNumber),
            TaxOffice = AccountNormalization.OptionalText(command.TaxOffice)
        };
        return await accounts.RegisterShipperAsync(normalized, cancellationToken);
    }
}

/// <summary>Taşımacı kaydını işler: doğrular, e-posta ve telefonu normalleştirir, hesabı oluşturur.</summary>
public sealed class RegisterCarrierHandler(IValidator<RegisterCarrierCommand> validator, IAccountService accounts)
    : ICommandHandler<RegisterCarrierCommand, RegisteredUserDto>
{
    /// <summary>Geçersizse <see cref="ValidationException"/>, e-posta/telefon kayıtlıysa <see cref="Common.ConflictException"/> fırlatır.</summary>
    public async Task<RegisteredUserDto> HandleAsync(RegisterCarrierCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);

        var normalized = command with
        {
            FullName = command.FullName!.Trim(),
            Email = AccountNormalization.Email(command.Email!),
            Phone = AccountNormalization.Phone(command.Phone!),
            Vehicles = command.Vehicles!.Select(v => v with { PlateNumber = AccountNormalization.OptionalText(v.PlateNumber) }).ToList()
        };
        return await accounts.RegisterCarrierAsync(normalized, cancellationToken);
    }
}

/// <summary>Kayıt verisinin tek biçime çevrilmesi: aynı e-posta/telefon farklı yazılışla iki hesap açamasın.</summary>
internal static class AccountNormalization
{
    /// <summary>E-posta: baş/son boşluk atılır, küçük harfe çevrilir.</summary>
    public static string Email(string email) => email.Trim().ToLowerInvariant();

    /// <summary>Telefon: <c>+905XXXXXXXXX</c> biçimi (doğrulamadan geçtiği için her zaman başarılıdır).</summary>
    public static string Phone(string phone) =>
        PhoneNumberNormalizer.TryNormalize(phone, out var normalized)
            ? normalized
            : throw new InvalidOperationException("Doğrulanmış telefon normalleştirilemedi.");

    /// <summary>İsteğe bağlı metin: baş/son boşluk atılır, geriye boş kalıyorsa <c>null</c> olur.</summary>
    public static string? OptionalText(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
