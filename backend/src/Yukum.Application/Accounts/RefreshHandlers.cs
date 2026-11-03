using FluentValidation;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Messaging;

namespace Yukum.Application.Accounts;

/// <summary>Yenileme ve çıkış komutlarının doğrulaması (boş alan 400).</summary>
public sealed class RefreshValidator : AbstractValidator<RefreshCommand>
{
    /// <summary>Kuralları kurar.</summary>
    public RefreshValidator()
    {
        RuleFor(c => c.RefreshToken).NotEmpty().WithMessage("Yenileme jetonu gerekli.").MaximumLength(200).WithMessage("Yenileme jetonu geçersiz.");
        RuleFor(c => c.DeviceId).NotEmpty().WithMessage("Cihaz kimliği gerekli.").MaximumLength(100).WithMessage("Cihaz kimliği en fazla 100 karakter olabilir.");
    }
}

/// <summary>Yenileme jetonuyla yeni erişim + yenileme jetonu çifti verir (rotasyon).</summary>
public sealed class RefreshHandler(IValidator<RefreshCommand> validator, IRefreshTokenService refreshTokens, ITokenService tokens)
    : ICommandHandler<RefreshCommand, LoginResponse>
{
    /// <summary>Jeton geçersizse InvalidRefreshTokenException (401).</summary>
    public async Task<LoginResponse> HandleAsync(RefreshCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);

        // Eski jeton iptal edilir, yenisi gelir; çalıntı/süresi dolmuş/başka cihaz ise burada 401 fırlar.
        var rotation = await refreshTokens.RotateAsync(command.RefreshToken!, command.DeviceId!.Trim(), cancellationToken);
        var access = tokens.CreateAccessToken(rotation.User);
        return new LoginResponse(access.Value, access.ExpiresAt, rotation.Token.Token, rotation.Token.ExpiresAt, rotation.User);
    }
}

/// <summary>Çıkış: jetonun cihazındaki tüm yenileme jetonlarını iptal eder. Jeton bilinmese de başarılı sayılır.</summary>
public sealed class LogoutHandler(IRefreshTokenService refreshTokens) : ICommandHandler<LogoutCommand, bool>
{
    /// <summary>Boş jeton da sessizce geçilir (çıkış her zaman sonuçlanır).</summary>
    public async Task<bool> HandleAsync(LogoutCommand command, CancellationToken cancellationToken = default)
    {
        if (!string.IsNullOrWhiteSpace(command.RefreshToken))
            await refreshTokens.RevokeAsync(command.RefreshToken, cancellationToken);
        return true;
    }
}
