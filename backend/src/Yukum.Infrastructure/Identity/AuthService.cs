using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Accounts;
using Yukum.Application.Common;

namespace Yukum.Infrastructure.Identity;

/// <summary>
/// <see cref="IAuthService"/>'in ASP.NET Core Identity ile gerçeği: şifre denetimi, hatalı deneme sayacı ve geçici kilit.
/// Güvenlik ilkeleri: (1) kullanıcı yok / şifre yanlış aynı cevabı verir, (2) kullanıcı olmasa bile şifre doğrulama süresi
/// kadar zaman harcanır (süre farkından "bu e-posta kayıtlı" anlaşılmasın), (3) hesap devre dışılığı yalnız doğru şifreden sonra söylenir.
/// </summary>
public sealed class AuthService(UserManager<AppUser> users, IPasswordHasher<AppUser> hasher, TimeProvider time) : IAuthService
{
    private const string UnavailableMessage = "Hesabınız şu an kullanılamıyor. Lütfen destek ile iletişime geçin.";

    // Kullanıcı bulunamadığında bu sahte hash'e karşı doğrulama yapılır; gerçek bir doğrulamayla aynı maliyettedir.
    private static readonly Lazy<string> DummyHash = new(() => new PasswordHasher<AppUser>().HashPassword(new AppUser(), "zamanlama-icin-sahte-sifre"));

    /// <inheritdoc />
    public async Task<AuthUserDto> VerifyCredentialsAsync(string? email, string? phone, string password, CancellationToken cancellationToken = default)
    {
        var user = email is not null
            ? await users.FindByEmailAsync(email)
            : await users.Users.FirstOrDefaultAsync(u => u.PhoneNumber == phone, cancellationToken);

        if (user is null)
        {
            hasher.VerifyHashedPassword(new AppUser(), DummyHash.Value, password);
            throw new InvalidCredentialsException();
        }

        if (await users.IsLockedOutAsync(user))
            throw new AccountLockedException(RemainingLock(user));

        if (!await users.CheckPasswordAsync(user, password))
        {
            user = await CountFailedAttemptAsync(user);
            if (await users.IsLockedOutAsync(user))
                throw new AccountLockedException(RemainingLock(user));
            throw new InvalidCredentialsException();
        }

        // Şifre doğru: artık hesabın durumunu söylemek güvenli (kullanıcı kimliğini kanıtladı).
        if (!user.IsActive || user.IsBlocked)
            throw new ForbiddenException(UnavailableMessage);

        await users.ResetAccessFailedCountAsync(user);

        var roles = await users.GetRolesAsync(user);
        if (roles.Count != 1)
            throw new InvalidOperationException($"Kullanıcının tam olarak bir rolü olmalı (bulunan: {roles.Count}).");

        return new AuthUserDto(user.Id, user.FullName, roles[0], user.AvatarUrl);
    }

    /// <summary>
    /// Hatalı denemeyi sayar; 5. hatada Identity kilidi koyar. Aynı hesaba eşzamanlı yanlış denemeler birbirinin sayımını
    /// ezebilir (eşzamanlılık çakışması); sayım kaybolmasın diye kullanıcı yeniden okunup birkaç kez denenir.
    /// </summary>
    private async Task<AppUser> CountFailedAttemptAsync(AppUser user)
    {
        for (var attempt = 0; attempt < 5; attempt++)
        {
            if ((await users.AccessFailedAsync(user)).Succeeded)
                return user;

            user = await users.FindByIdAsync(user.Id.ToString()) ?? user;
        }

        return user;
    }

    private TimeSpan RemainingLock(AppUser user)
    {
        var remaining = (user.LockoutEnd ?? time.GetUtcNow()) - time.GetUtcNow();
        return remaining > TimeSpan.Zero ? remaining : TimeSpan.Zero;
    }
}
