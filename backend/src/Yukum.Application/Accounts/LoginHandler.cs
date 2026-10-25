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
        // 1) Alanlar dolu mu, makul uzunlukta mı? Değilse ValidationException fırlar → 400; aşağıya hiç inilmez.
        await validator.ValidateAndThrowAsync(command, cancellationToken);

        // "@" içeriyorsa e-postadır; değilse cep telefonu olmalıdır. İkisi de değilse kimse bu girişle kayıtlı olamaz:
        // ayrı bir hata değil, aynı genel "hatalı giriş" cevabı verilir.
        // '!' işareti: doğrulama geçtiği için bu alanın boş olmadığını biliyoruz.
        var typed = command.EmailOrPhone!.Trim();
        string? email = null;
        string? phone = null;
        // 2) Kimlik türünü belirle: e-posta mı, telefon mu?
        if (typed.Contains('@'))
            // E-posta küçük harfe çevrilir (kayıtta da küçük harfle saklanıyor).
            email = typed.ToLowerInvariant();
        else if (PhoneNumberNormalizer.TryNormalize(typed, out var normalizedPhone))
            // Telefon +905... biçimine çevrilir.
            phone = normalizedPhone;
        else
            // Ne e-posta ne telefon: ayrı hata değil, genel 'hatalı giriş' (401).
            throw new InvalidCredentialsException();

        // Şifreye dokunulmaz (boşluk ve büyük/küçük harf anlamlıdır).
        // 3) Şifre denetimi, hatalı deneme sayacı ve kilit burada (Infrastructure/AuthService.cs). Başarısızsa istisna fırlatır.
        var user = await auth.VerifyCredentialsAsync(email, phone, command.Password!, cancellationToken);
        // 4) Şifre doğruysa 15 dakikalık JWT erişim jetonu üret (Infrastructure/JwtTokenService.cs).
        var token = tokens.CreateAccessToken(user);

        // 5) Jeton + bitiş zamanı + kullanıcı özeti istemciye döner.
        return new LoginResponse(token.Value, token.ExpiresAt, user);
    }
}
