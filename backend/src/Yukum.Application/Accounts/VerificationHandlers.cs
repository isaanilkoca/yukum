using FluentValidation;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Domain.Accounts;

namespace Yukum.Application.Accounts;

/// <summary>Ortak kurallar: e-posta/telefon ve rol (Shipper/Carrier) zorunlu; kod 6 rakam.</summary>
internal static class VerificationRules
{
    public static IRuleBuilderOptions<T, string?> RequiredIdentity<T>(this IRuleBuilder<T, string?> rule) =>
        rule.NotEmpty().WithMessage("E-posta ya da telefon boş olamaz.");

    public static IRuleBuilderOptions<T, string?> RequiredRole<T>(this IRuleBuilder<T, string?> rule) =>
        rule.Must(r => LoginHandler.TryParseRole(r, out _)).WithMessage("Hesap türünü (Yük Veren / Taşımacı) seç.");

    public static IRuleBuilderOptions<T, string?> SixDigitCode<T>(this IRuleBuilder<T, string?> rule) =>
        rule.Must(c => c?.Trim() is { Length: 6 } t && t.All(char.IsAsciiDigit)).WithMessage("Kod 6 rakamdan oluşmalı.");

    public static UserType Role(string? text) { LoginHandler.TryParseRole(text, out var role); return role; }
}

/// <summary>Kural: e-posta + rol.</summary>
public sealed class SendVerificationCodeValidator : AbstractValidator<SendVerificationCodeCommand>
{
    /// <summary>Kuralları kurar.</summary>
    public SendVerificationCodeValidator() { RuleFor(c => c.EmailOrPhone).RequiredIdentity(); RuleFor(c => c.Role).RequiredRole(); }
}

/// <summary>Kural: e-posta + rol + 6 haneli kod.</summary>
public sealed class VerifyEmailValidator : AbstractValidator<VerifyEmailCommand>
{
    /// <summary>Kuralları kurar.</summary>
    public VerifyEmailValidator() { RuleFor(c => c.EmailOrPhone).RequiredIdentity(); RuleFor(c => c.Role).RequiredRole(); RuleFor(c => c.Code).SixDigitCode(); }
}

/// <summary>Kural: e-posta + rol.</summary>
public sealed class ForgotPasswordValidator : AbstractValidator<ForgotPasswordCommand>
{
    /// <summary>Kuralları kurar.</summary>
    public ForgotPasswordValidator() { RuleFor(c => c.EmailOrPhone).RequiredIdentity(); RuleFor(c => c.Role).RequiredRole(); }
}

/// <summary>Kural: e-posta + rol + kod + kayıttaki şifre kuralı (PasswordPolicy, tek kaynak).</summary>
public sealed class ResetPasswordValidator : AbstractValidator<ResetPasswordCommand>
{
    /// <summary>Kuralları kurar.</summary>
    public ResetPasswordValidator()
    {
        RuleFor(c => c.EmailOrPhone).RequiredIdentity(); RuleFor(c => c.Role).RequiredRole(); RuleFor(c => c.Code).SixDigitCode();
        RuleFor(c => c.NewPassword).Password(); // ⮕ RegisterValidators.AccountRules.Password: kayıttaki kuralın aynısı
    }
}

/// <summary>Doğrulama kodunu (yeniden) gönderir. Her zaman başarılı (e-postanın kayıtlı olup olmadığı sızdırılmaz).</summary>
public sealed class SendVerificationCodeHandler(IValidator<SendVerificationCodeCommand> validator, IVerificationService verification)
    : ICommandHandler<SendVerificationCodeCommand, bool>
{
    /// <summary>Biçim hatası 400; gerisi 204.</summary>
    public async Task<bool> HandleAsync(SendVerificationCodeCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);
        await verification.SendCodeAsync(command.EmailOrPhone!.Trim(), VerificationRules.Role(command.Role), VerificationPurpose.EmailVerification, cancellationToken);
        return true;
    }
}

/// <summary>E-posta doğrulama kodunu kontrol eder.</summary>
public sealed class VerifyEmailHandler(IValidator<VerifyEmailCommand> validator, IVerificationService verification) : ICommandHandler<VerifyEmailCommand, bool>
{
    /// <summary>Kod yanlış/süresi dolmuş 400.</summary>
    public async Task<bool> HandleAsync(VerifyEmailCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);
        await verification.VerifyEmailAsync(command.EmailOrPhone!.Trim(), VerificationRules.Role(command.Role), command.Code!.Trim(), cancellationToken);
        return true;
    }
}

/// <summary>Şifremi unuttum: sıfırlama kodu gönderir. Her zaman başarılı (kayıtlı mı sızdırılmaz).</summary>
public sealed class ForgotPasswordHandler(IValidator<ForgotPasswordCommand> validator, IVerificationService verification) : ICommandHandler<ForgotPasswordCommand, bool>
{
    /// <summary>Biçim hatası 400; gerisi 204.</summary>
    public async Task<bool> HandleAsync(ForgotPasswordCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);
        await verification.SendCodeAsync(command.EmailOrPhone!.Trim(), VerificationRules.Role(command.Role), VerificationPurpose.PasswordReset, cancellationToken);
        return true;
    }
}

/// <summary>Kod + yeni şifre: şifreyi değiştirir.</summary>
public sealed class ResetPasswordHandler(IValidator<ResetPasswordCommand> validator, IVerificationService verification) : ICommandHandler<ResetPasswordCommand, bool>
{
    /// <summary>Şifre kuralı / kod hatası 400.</summary>
    public async Task<bool> HandleAsync(ResetPasswordCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);
        await verification.ResetPasswordAsync(command.EmailOrPhone!.Trim(), VerificationRules.Role(command.Role), command.Code!.Trim(), command.NewPassword!, cancellationToken);
        return true;
    }
}
