using FluentValidation;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Common;

namespace Yukum.Application.Accounts;

/// <summary>Girişi işler: doğrular, kimliği (e-posta/telefon) çözer, şifreyi denetler, erişim jetonu üretir.</summary>
public sealed class LoginHandler(IValidator<LoginCommand> validator, IAuthService auth, ITokenService tokens)
    : ICommandHandler<LoginCommand, LoginResponse>
{
    /// <summary>
    /// Alan eksikse <see cref="ValidationException"/>; kullanıcı/şifre yanlışsa <see cref="InvalidCredentialsException"/>;
    /// kilitliyse <see cref="AccountLockedException"/>; hesap devre dışıysa <see cref="ForbiddenException"/> fırlatır.
    /// </summary>
    public async Task<LoginResponse> HandleAsync(LoginCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);

        // "@" içeriyorsa e-postadır; değilse cep telefonu olmalıdır. İkisi de değilse kimse bu girişle kayıtlı olamaz:
        // ayrı bir hata değil, aynı genel "hatalı giriş" cevabı verilir.
        var typed = command.EmailOrPhone!.Trim();
        string? email = null;
        string? phone = null;
        if (typed.Contains('@'))
            email = typed.ToLowerInvariant();
        else if (PhoneNumberNormalizer.TryNormalize(typed, out var normalizedPhone))
            phone = normalizedPhone;
        else
            throw new InvalidCredentialsException();

        // Şifreye dokunulmaz (boşluk ve büyük/küçük harf anlamlıdır).
        var user = await auth.VerifyCredentialsAsync(email, phone, command.Password!, cancellationToken);
        var token = tokens.CreateAccessToken(user);

        return new LoginResponse(token.Value, token.ExpiresAt, user);
    }
}
