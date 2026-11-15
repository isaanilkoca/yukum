using FluentValidation;
using FluentValidation.Results;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Accounts;
using Yukum.Application.Common;
using Yukum.Domain.Accounts;

namespace Yukum.Infrastructure.Identity;

/// <summary>
/// <see cref="IAuthService"/>'in ASP.NET Core Identity ile gerçeği: şifre denetimi, hatalı deneme sayacı ve geçici kilit.
/// Güvenlik ilkeleri: (1) kullanıcı yok / şifre yanlış aynı cevabı verir, (2) kullanıcı olmasa bile şifre doğrulama süresi
/// kadar zaman harcanır (süre farkından "bu e-posta kayıtlı" anlaşılmasın), (3) hesap devre dışılığı yalnız doğru şifreden sonra söylenir.
/// </summary>
public sealed class AuthService(UserManager<AppUser> users, IPasswordHasher<AppUser> hasher, TimeProvider time,
    Microsoft.Extensions.Options.IOptions<VerificationOptions> verification) : IAuthService
{
    private const string UnavailableMessage = "Hesabınız şu an kullanılamıyor. Lütfen destek ile iletişime geçin.";

    // Kullanıcı bulunamadığında bu sahte hash'e karşı doğrulama yapılır; gerçek bir doğrulamayla aynı maliyettedir.
    private static readonly Lazy<string> DummyHash = new(() => new PasswordHasher<AppUser>().HashPassword(new AppUser(), "zamanlama-icin-sahte-sifre"));

    /// <inheritdoc />
    public async Task<AuthUserDto> VerifyCredentialsAsync(string? email, string? phone, string password, UserType? type, CancellationToken cancellationToken = default)
    {
        // Kullanıcıyı bul: e-postayla (Identity büyük harfli normalleştirilmiş sütunda arar) ya da telefonla.
        // Aynı e-posta/telefon iki rolde olabilir (K-022): istemci rolü gönderir ve yalnız o rolün hesabı aranır.
        // Rol gönderilmemişse ve tek eşleşme varsa o hesap, birden fazlaysa istemci rol seçmeli (400).
        var normalizedEmail = email is not null ? users.NormalizeEmail(email) : null;
        var matches = await users.Users
            .Where(u => (normalizedEmail != null ? u.NormalizedEmail == normalizedEmail : u.PhoneNumber == phone) && (type == null || u.UserType == type))
            .Take(2).ToListAsync(cancellationToken);
        if (matches.Count > 1)
            throw new ValidationException([new ValidationFailure("role", "Bu bilgiyle iki hesap var; giriş yapmak istediğin hesabı (Yük Veren / Taşımacı) seç.")]);
        var user = matches.SingleOrDefault();

        // Kullanıcı yok: yine de bir şifre doğrulaması yapılır ki cevap süresi gerçek kullanıcıyla aynı olsun (zamanlama saldırısı).
        if (user is null)
        {
            // Sonuç kullanılmaz; yalnız aynı süreyi harcar.
            hasher.VerifyHashedPassword(new AppUser(), DummyHash.Value, password);
            throw new InvalidCredentialsException();
        }

        // Hesap kilitli mi? Kilitliyse şifreye hiç bakılmaz (423).
        if (await users.IsLockedOutAsync(user))
            throw new AccountLockedException(RemainingLock(user));

        // Şifre doğru mu? Hash karşılaştırması yapılır; şifre açık metin olarak saklanmaz.
        if (!await users.CheckPasswordAsync(user, password))
        {
            // Hatalı denemeyi say; 5. hatada Identity kilidi koyar.
            user = await CountFailedAttemptAsync(user);
            // Bu deneme kilidi başlattı mı? Başlattıysa hemen 423, değilse genel 401.
            if (await users.IsLockedOutAsync(user))
                throw new AccountLockedException(RemainingLock(user));
            throw new InvalidCredentialsException();
        }

        // Şifre doğru: artık hesabın durumunu söylemek güvenli (kullanıcı kimliğini kanıtladı).
        if (!user.IsActive || user.IsBlocked)
            throw new ForbiddenException(UnavailableMessage);
        // 15 Kasım (kullanıcı kararı): e-postası doğrulanmamış hesap giriş yapamaz. Şifre DOĞRUYSA söylenir (yabancıya hesap durumu sızmaz).
        if (verification.Value.RequireVerifiedEmail && !user.EmailConfirmed)
            throw new EmailNotVerifiedException();

        // Başarılı giriş: hatalı deneme sayacı sıfırlanır.
        await users.ResetAccessFailedCountAsync(user);

        // Rolü Identity'den al: yetki kontrolünün baktığı gerçek kaynak budur.
        var roles = await users.GetRolesAsync(user);
        if (roles.Count != 1)
            throw new InvalidOperationException($"Kullanıcının tam olarak bir rolü olmalı (bulunan: {roles.Count}).");

        // İstemciye gidecek sade özet.
        return new AuthUserDto(user.Id, user.FullName, roles[0], user.AvatarUrl);
    }

    /// <summary>
    /// Hatalı denemeyi sayar; 5. hatada Identity kilidi koyar. Aynı hesaba eşzamanlı yanlış denemeler birbirinin sayımını
    /// ezebilir (eşzamanlılık çakışması); sayım kaybolmasın diye kullanıcı yeniden okunup birkaç kez denenir.
    /// </summary>
    private async Task<AppUser> CountFailedAttemptAsync(AppUser user)
    {
        // En fazla 5 kez dene (eşzamanlı güncelleme çakışması ihtimaline karşı).
        for (var attempt = 0; attempt < 5; attempt++)
        {
            // Sayacı +1 yapar; 5'e ulaşırsa kilit bitiş zamanını da yazar.
            if ((await users.AccessFailedAsync(user)).Succeeded)
                return user;

            // Çakışma oldu (başka bir istek araya girdi): kullanıcıyı güncel haliyle yeniden oku ve tekrar dene.
            user = await users.FindByIdAsync(user.Id.ToString()) ?? user;
        }

        return user;
    }

    private TimeSpan RemainingLock(AppUser user)
    {
        // Kilidin açılmasına kalan süre (negatifse 0).
        var remaining = (user.LockoutEnd ?? time.GetUtcNow()) - time.GetUtcNow();
        return remaining > TimeSpan.Zero ? remaining : TimeSpan.Zero;
    }
}
