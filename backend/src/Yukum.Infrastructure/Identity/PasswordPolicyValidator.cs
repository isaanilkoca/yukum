using Microsoft.AspNetCore.Identity;
using Yukum.Application.Accounts;

namespace Yukum.Infrastructure.Identity;

/// <summary>
/// Identity'nin şifre doğrulamasına <see cref="PasswordPolicy"/> kuralını bağlar. Identity'nin kendi büyük/küçük harf
/// kontrolü yalnız A–Z (ASCII) bakar, Türkçe harfli "Şifre1234" gibi geçerli şifreleri yanlışlıkla reddederdi.
/// Kayıt doğrulaması ile Identity böylece aynı kuralı, aynı kod üzerinden uygular.
/// </summary>
public sealed class PasswordPolicyValidator : IPasswordValidator<AppUser>
{
    /// <inheritdoc />
    public Task<IdentityResult> ValidateAsync(UserManager<AppUser> manager, AppUser user, string? password)
    {
        if (!string.IsNullOrEmpty(password) && PasswordPolicy.IsValid(password))
            return Task.FromResult(IdentityResult.Success);

        return Task.FromResult(IdentityResult.Failed(new IdentityError
        {
            Code = "PasswordPolicy",
            Description = "Şifre en az 8 karakter olmalı; büyük harf, küçük harf ve rakam içermeli."
        }));
    }
}
