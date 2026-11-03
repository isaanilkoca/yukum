using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Accounts;
using Yukum.Application.Common;
using Yukum.Domain.Accounts;
using Yukum.Infrastructure.Persistence;

namespace Yukum.Infrastructure.Identity;

/// <summary><see cref="IRefreshTokenService"/> gerçeklemesi: rotasyon + çalıntı (reuse) tespiti (yalnız rotasyonla yenilenmiş jeton için) + eşzamanlılık koruması.</summary>
public sealed class RefreshTokenService(
    AppDbContext context,
    UserManager<AppUser> users,
    IOptions<JwtOptions> options,
    TimeProvider time) : IRefreshTokenService
{
    /// <inheritdoc />
    public async Task<RefreshTokenIssue> IssueAsync(Guid userId, string deviceId, CancellationToken cancellationToken = default)
    {
        var now = time.GetUtcNow().UtcDateTime;

        // Cihaz başına tek oturum: aynı kullanıcı + cihazın eski aktif jetonları iptal edilir.
        await RevokeFamilyAsync(userId, deviceId, now, cancellationToken);

        var (raw, entity) = Create(userId, deviceId, now);
        context.RefreshTokens.Add(entity);
        await context.SaveChangesAsync(cancellationToken);
        return new RefreshTokenIssue(raw, entity.ExpiresAt);
    }

    /// <inheritdoc />
    public async Task<RefreshTokenRotation> RotateAsync(string rawToken, string deviceId, CancellationToken cancellationToken = default)
    {
        var now = time.GetUtcNow().UtcDateTime;
        var hash = Hash(rawToken);
        var token = await context.RefreshTokens.FirstOrDefaultAsync(t => t.TokenHash == hash, cancellationToken)
                    ?? throw new InvalidRefreshTokenException();

        if (token.RevokedAt is not null)
        {
            // ÇALINTI TESPİTİ: rotasyonla YENİLENMİŞ (yerine yenisi geçmiş) jeton tekrar kullanıldı. Meşru istemci eskisini artık
            // göndermez; gönderen çalıntı kopyayı tutan biridir. Güvenli tarafta kalıp o cihazın tüm jeton ailesini iptal ederiz.
            // Çıkışla ya da yeniden girişle iptal edilmiş jeton (ReplacedByTokenId boş) çalıntı sayılmaz, yalnız reddedilir:
            // aksi hâlde eski bir kopya, kullanıcının geçerli yeni oturumunu da düşürürdü.
            if (token.ReplacedByTokenId is not null)
                await RevokeFamilyAsync(token.UserId, token.DeviceId, now, cancellationToken);
            throw new InvalidRefreshTokenException();
        }

        // Süresi dolmuş ya da başka cihazdan geliyor: çalıntı olabilir, reddedilir.
        if (token.ExpiresAt <= now || !string.Equals(token.DeviceId, deviceId, StringComparison.Ordinal))
            throw new InvalidRefreshTokenException();

        // Kullanıcı hâlâ geçerli mi? (silinmiş, pasif, engelli ya da kilitli hesaba jeton yenilenmez)
        var user = await users.FindByIdAsync(token.UserId.ToString());
        if (user is null || !user.IsActive || user.IsBlocked || await users.IsLockedOutAsync(user))
            throw new InvalidRefreshTokenException();
        var roles = await users.GetRolesAsync(user);
        if (roles.Count != 1) throw new InvalidOperationException($"Kullanıcının tam olarak bir rolü olmalı (bulunan: {roles.Count}).");

        // ROTASYON: yenisi eklenir, eskisi iptal edilip "yerine geçen" işaretlenir.
        var (raw, next) = Create(token.UserId, token.DeviceId, now);
        context.RefreshTokens.Add(next);
        token.RevokedAt = now;
        token.ReplacedByTokenId = next.Id;

        try
        {
            await context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            // Aynı jetonla iki istek aynı anda geldi: RowVersion yalnız birine izin verir, ikincisi buraya düşer.
            throw new InvalidRefreshTokenException();
        }

        return new RefreshTokenRotation(new AuthUserDto(user.Id, user.FullName, roles[0], user.AvatarUrl), new RefreshTokenIssue(raw, next.ExpiresAt));
    }

    /// <inheritdoc />
    public async Task RevokeAsync(string rawToken, CancellationToken cancellationToken = default)
    {
        var hash = Hash(rawToken);
        var token = await context.RefreshTokens.AsNoTracking().FirstOrDefaultAsync(t => t.TokenHash == hash, cancellationToken);
        if (token is null) return;   // bilinmeyen jeton: çıkış yine de "başarılı" (bilgi sızdırılmaz)
        await RevokeFamilyAsync(token.UserId, token.DeviceId, time.GetUtcNow().UtcDateTime, cancellationToken);
    }

    // Aynı kullanıcı + cihazın aktif (iptal edilmemiş) tüm jetonlarını tek SQL UPDATE ile iptal eder.
    private Task<int> RevokeFamilyAsync(Guid userId, string deviceId, DateTime now, CancellationToken ct) =>
        context.RefreshTokens
            .Where(t => t.UserId == userId && t.DeviceId == deviceId && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, now), ct);

    // Yeni jeton: 32 baytlık kriptografik rastgele sayı (256 bit), URL'ye uygun metin. DB'ye yalnız SHA-256 özeti yazılır.
    private (string Raw, RefreshToken Entity) Create(Guid userId, string deviceId, DateTime now)
    {
        var raw = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        var entity = new RefreshToken
        {
            UserId = userId,
            DeviceId = deviceId,
            TokenHash = Hash(raw),
            ExpiresAt = now.AddDays(options.Value.RefreshTokenDays)
        };
        return (raw, entity);
    }

    // SHA-256 özeti, 64 karakterlik onaltılık metin (DB sütunu 64 karakter). Jetonun kendisi yüksek entropili olduğu için tuzsuz hash yeterlidir.
    private static string Hash(string raw) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(raw)));
}
