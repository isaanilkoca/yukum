using Microsoft.EntityFrameworkCore;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Domain.Notifications;

namespace Yukum.Infrastructure.Persistence;

/// <summary><see cref="IDeviceTokenRepository"/>'nin EF Core uygulaması. Jeton benzersiz indeksli: çift kayıt veritabanında engellenir.</summary>
public class DeviceTokenRepository(AppDbContext context) : IDeviceTokenRepository
{
    /// <inheritdoc />
    public async Task UpsertAsync(Guid userId, string deviceId, string token, bool sandbox, CancellationToken cancellationToken = default)
    {
        // Aynı cihazın ESKİ jetonu (Apple jetonu yenilediyse) silinir: bir cihaz = bir adres
        await context.Set<DeviceToken>().Where(d => d.DeviceId == deviceId && d.Token != token).ExecuteDeleteAsync(cancellationToken);

        // Jeton zaten kayıtlıysa sahibini güncelle (aynı telefonda başka hesapla giriş): tek UPDATE, 0 satır = kayıt yok
        var updated = await context.Set<DeviceToken>().Where(d => d.Token == token)
            .ExecuteUpdateAsync(s => s.SetProperty(d => d.UserId, userId).SetProperty(d => d.DeviceId, deviceId).SetProperty(d => d.Sandbox, sandbox),
                cancellationToken);
        if (updated > 0) return;

        var entity = new DeviceToken { UserId = userId, DeviceId = deviceId, Token = token, Sandbox = sandbox };
        context.Add(entity);
        try { await context.SaveChangesAsync(cancellationToken); }
        catch (DbUpdateException)
        {
            // İki istek aynı anda aynı jetonu ekledi: benzersiz indeks ikincisini reddeder. Kayıt zaten var, hata değil.
            context.Entry(entity).State = EntityState.Detached;
        }
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<DeviceToken>> ListForUsersAsync(IReadOnlyCollection<Guid> userIds, CancellationToken cancellationToken = default) =>
        await context.Set<DeviceToken>().AsNoTracking().Where(d => userIds.Contains(d.UserId)).ToListAsync(cancellationToken);

    /// <inheritdoc />
    public Task RemoveForDeviceAsync(Guid userId, string deviceId, CancellationToken cancellationToken = default) =>
        context.Set<DeviceToken>().Where(d => d.UserId == userId && d.DeviceId == deviceId).ExecuteDeleteAsync(cancellationToken);

    /// <inheritdoc />
    public Task RemoveByTokenAsync(string token, CancellationToken cancellationToken = default) =>
        context.Set<DeviceToken>().Where(d => d.Token == token).ExecuteDeleteAsync(cancellationToken);

    /// <inheritdoc />
    public Task DeleteUserDataAsync(Guid userId, CancellationToken cancellationToken = default) =>
        context.Set<DeviceToken>().Where(d => d.UserId == userId).ExecuteDeleteAsync(cancellationToken);
}
