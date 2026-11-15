using System.Security.Cryptography;
using System.Text;
using FluentValidation;
using FluentValidation.Results;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Accounts;
using Yukum.Domain.Accounts;
using Yukum.Infrastructure.Persistence;

namespace Yukum.Infrastructure.Identity;

/// <summary><see cref="IVerificationService"/> uygulaması: kod üret/sakla (özet), e-postayla gönder, doğrula, şifre değiştir.</summary>
// ZİNCİR (şifremi unuttum): iOS ForgotPassword ekranı → POST /auth/password/forgot → ForgotPasswordHandler → SendCodeAsync
//   → kod e-postası → iOS kod + yeni şifre → POST /auth/password/reset → ResetPasswordAsync → şifre değişir, tüm cihazlarda oturum kapanır
public sealed class VerificationService(AppDbContext context, UserManager<AppUser> users, IEmailSender email, TimeProvider time) : IVerificationService
{
    // Kurallar tek yerde (rakamlar OWASP önerilerine göre kısa ömür + az deneme)
    private static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(15);
    private static readonly TimeSpan ResendCooldown = TimeSpan.FromSeconds(60);
    private const int MaxAttempts = 5;
    private const string InvalidCodeMessage = "Kod hatalı ya da süresi dolmuş. Yeni kod isteyebilirsin.";

    /// <inheritdoc />
    public async Task SendCodeAsync(string emailOrPhone, UserType role, VerificationPurpose purpose, CancellationToken cancellationToken = default)
    {
        var user = await FindAsync(emailOrPhone, role, cancellationToken);
        // Kullanıcı yok ya da zaten doğrulanmış: sessizce çık (cevap aynı → "kayıtlı mı" yoklanamaz)
        if (user is null || (purpose == VerificationPurpose.EmailVerification && user.EmailConfirmed)) return;

        var now = time.GetUtcNow().UtcDateTime;
        var codes = context.Set<VerificationCode>();
        // 60 sn içinde yeni kod yok: e-posta kutusunu doldurmayı (ve servis kotasını harcamayı) engeller. iOS düğmeyi 60 sn kilitler.
        if (await codes.AnyAsync(c => c.UserId == user.Id && c.Purpose == purpose && c.CreatedAt > now - ResendCooldown, cancellationToken)) return;

        // Yeni kod eskileri geçersiz kılar: aynı anda tek geçerli kod (kalıcı silme: iz gerekmez)
        await codes.Where(c => c.UserId == user.Id && c.Purpose == purpose).ExecuteDeleteAsync(cancellationToken);

        // RandomNumberGenerator [.NET]: kriptografik rastgele (Random tahmin edilebilir) | "D6": baştaki sıfırlar korunur (004215)
        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        codes.Add(new VerificationCode { UserId = user.Id, Purpose = purpose, CodeHash = Hash(user.Id, code), ExpiresAt = now + Lifetime });
        await context.SaveChangesAsync(cancellationToken);

        var (subject, intro) = purpose == VerificationPurpose.EmailVerification
            ? ("Yüküm e-posta doğrulama kodun", "Yüküm hesabını doğrulamak için bu kodu uygulamaya gir:")
            : ("Yüküm şifre sıfırlama kodun", "Şifreni sıfırlamak için bu kodu uygulamaya gir:");
        await email.SendAsync(user.Email!, subject,
            $"Merhaba {user.FullName},\n\n{intro}\n\n{code}\n\nKod 15 dakika geçerlidir. Bu isteği sen yapmadıysan bu e-postayı yok sayabilirsin.\n\nYüküm",
            cancellationToken);
    }

    /// <inheritdoc />
    public async Task VerifyEmailAsync(string emailOrPhone, UserType role, string code, CancellationToken cancellationToken = default)
    {
        var user = await FindAsync(emailOrPhone, role, cancellationToken) ?? throw Invalid();
        if (user.EmailConfirmed) return; // zaten doğrulanmış: tekrar basılırsa da başarılı (idempotent)
        await ConsumeAsync(user, VerificationPurpose.EmailVerification, code, cancellationToken);
        user.EmailConfirmed = true;
        await users.UpdateAsync(user);
    }

    /// <inheritdoc />
    public async Task ResetPasswordAsync(string emailOrPhone, UserType role, string code, string newPassword, CancellationToken cancellationToken = default)
    {
        var user = await FindAsync(emailOrPhone, role, cancellationToken) ?? throw Invalid();
        // Önce şifre kuralı (kod HARCANMADAN: zayıf şifre yazan kullanıcı yeni kod istemek zorunda kalmasın)
        foreach (var validator in users.PasswordValidators)
        {
            var check = await validator.ValidateAsync(users, user, newPassword);
            if (!check.Succeeded) throw new ValidationException([new ValidationFailure("newPassword", check.Errors.First().Description)]);
        }
        await ConsumeAsync(user, VerificationPurpose.PasswordReset, code, cancellationToken);

        // Şifre Identity'nin KENDİ doğrulayıcılarından geçer (kayıttaki kural, PasswordPolicy) ve kendi hash'leyicisiyle saklanır.
        // NEDEN jetonlu ResetPasswordAsync değil: o yol Identity "token provider" (DataProtection) ister; bizde kodun kendisi zaten kanıt.
        user.PasswordHash = users.PasswordHasher.HashPassword(user, newPassword);
        user.SecurityStamp = Guid.NewGuid().ToString(); // güvenlik damgası: "kimlik bilgisi değişti" işareti
        user.EmailConfirmed = true;      // koda ulaşabildi = e-posta onun
        user.LockoutEnd = null;          // hatalı denemelerle kilitlendiyse açılır
        user.AccessFailedCount = 0;
        await users.UpdateAsync(user);
        // Tüm cihazlardaki oturumlar kapanır: şifre çalındıysa saldırganın açık oturumu da biter
        var now = time.GetUtcNow().UtcDateTime;
        await context.RefreshTokens.Where(t => t.UserId == user.Id && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, now), cancellationToken);
    }

    // Son kodu bulur, süresini/deneme sayısını ve eşleşmeyi kontrol eder; doğruysa kullanılmış işaretler. Yanlışsa sayaç artar ve 400.
    private async Task ConsumeAsync(AppUser user, VerificationPurpose purpose, string code, CancellationToken ct)
    {
        var now = time.GetUtcNow().UtcDateTime;
        var entry = await context.Set<VerificationCode>()
            .Where(c => c.UserId == user.Id && c.Purpose == purpose && c.UsedAt == null)
            .OrderByDescending(c => c.CreatedAt).FirstOrDefaultAsync(ct);
        if (entry is null || entry.ExpiresAt <= now || entry.Attempts >= MaxAttempts) throw Invalid();

        // FixedTimeEquals: karşılaştırma süresi kaç harfin tuttuğuna göre değişmez (zamanlama saldırısı)
        var match = CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(entry.CodeHash), Encoding.ASCII.GetBytes(Hash(user.Id, code)));
        if (!match)
        {
            entry.Attempts++;
            await context.SaveChangesAsync(ct);
            throw Invalid();
        }
        entry.UsedAt = now;
        await context.SaveChangesAsync(ct);
    }

    // E-posta YA DA telefon + rol → hesap (girişteki kural: @ varsa e-posta, yoksa telefon +905… biçimine çevrilir)
    //   silinmiş/anonim hesaplar e-postası/telefonu değiştiği için bulunmaz
    private Task<AppUser?> FindAsync(string emailOrPhone, UserType role, CancellationToken ct)
    {
        if (emailOrPhone.Contains('@'))
        {
            var normalized = users.NormalizeEmail(emailOrPhone.ToLowerInvariant());
            return users.Users.FirstOrDefaultAsync(u => u.NormalizedEmail == normalized && u.UserType == role, ct);
        }
        if (!PhoneNumberNormalizer.TryNormalize(emailOrPhone, out var phone)) return Task.FromResult<AppUser?>(null);
        return users.Users.FirstOrDefaultAsync(u => u.PhoneNumber == phone && u.UserType == role, ct);
    }

    // SHA-256(kullanıcı numarası + ":" + kod) → 64 onaltılık harf | kullanıcı numarası tuz: aynı kod iki kişide farklı özet verir
    private static string Hash(Guid userId, string code) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes($"{userId}:{code}")));

    private static ValidationException Invalid() => new([new ValidationFailure("code", InvalidCodeMessage)]);
}
