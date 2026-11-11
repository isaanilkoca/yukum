using Microsoft.EntityFrameworkCore;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Domain.Notifications;

namespace Yukum.Infrastructure.Persistence;

/// <summary><see cref="INotificationRepository"/>'nin EF Core uygulaması. Okundu işaretleme tek SQL UPDATE (SELECT yok), her sorgu UserId ile sınırlı: başkasının bildirimine dokunulamaz.</summary>
public class NotificationRepository(AppDbContext context) : INotificationRepository
{
    /// <inheritdoc />
    public async Task<(IReadOnlyList<Notification> Items, int Total)> ListAsync(Guid userId, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        var query = context.Set<Notification>().AsNoTracking().Where(n => n.UserId == userId);
        var total = await query.CountAsync(cancellationToken);
        // Kararlı sıra: aynı anda oluşanlar için Id ikinci anahtar (sayfalarda tekrar/kayıp olmasın)
        var items = await query.OrderByDescending(n => n.CreatedAt).ThenByDescending(n => n.Id)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(cancellationToken);
        return (items, total);
    }

    /// <inheritdoc />
    public Task<int> CountUnreadAsync(Guid userId, CancellationToken cancellationToken = default) =>
        context.Set<Notification>().CountAsync(n => n.UserId == userId && n.ReadAt == null, cancellationToken);

    /// <inheritdoc />
    public async Task<bool> MarkReadAsync(Guid userId, Guid notificationId, DateTime now, CancellationToken cancellationToken = default)
    {
        // Önce "var mı ve benim mi": yoksa/başkasınınsa false (404). Sonra yalnız okunmamışı güncelle: ikinci çağrı değiştirmez (idempotent).
        if (!await context.Set<Notification>().AnyAsync(n => n.Id == notificationId && n.UserId == userId, cancellationToken)) return false;
        await context.Set<Notification>().Where(n => n.Id == notificationId && n.UserId == userId && n.ReadAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.ReadAt, now).SetProperty(n => n.UpdatedAt, now), cancellationToken);
        return true;
    }

    /// <inheritdoc />
    public Task<int> MarkAllReadAsync(Guid userId, DateTime now, CancellationToken cancellationToken = default) =>
        context.Set<Notification>().Where(n => n.UserId == userId && n.ReadAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.ReadAt, now).SetProperty(n => n.UpdatedAt, now), cancellationToken);

    /// <inheritdoc />
    public async Task<IReadOnlyList<Notification>> ListUnpushedAsync(int take, CancellationToken cancellationToken = default) =>
        await context.Set<Notification>().AsNoTracking().Where(n => n.PushedAt == null)
            .OrderBy(n => n.CreatedAt).ThenBy(n => n.Id).Take(take).ToListAsync(cancellationToken);

    /// <inheritdoc />
    public Task MarkPushedAsync(IReadOnlyCollection<Guid> ids, DateTime now, CancellationToken cancellationToken = default) =>
        // PushedAt == null koşulu: iki işçi aynı satırı işaretlemeye çalışırsa ikincisi 0 satır etkiler
        context.Set<Notification>().Where(n => ids.Contains(n.Id) && n.PushedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.PushedAt, now), cancellationToken);

    /// <inheritdoc />
    public Task DeleteUserDataAsync(Guid userId, CancellationToken cancellationToken = default) =>
        context.Set<Notification>().Where(n => n.UserId == userId).ExecuteDeleteAsync(cancellationToken);
}
