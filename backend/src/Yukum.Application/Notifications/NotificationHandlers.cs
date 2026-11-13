using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;

namespace Yukum.Application.Notifications;

/// <summary>Kullanıcının bildirim listesi (en yeni üstte, sayfalı).</summary>
public sealed class GetNotificationsHandler(INotificationRepository notifications)
    : IQueryHandler<GetNotificationsQuery, PagedResult<NotificationDto>>
{
    // FONKSİYON ROLÜ: API'NİN İŞ MANTIĞI | NotificationsController çağırır: yalnız İSTEYEN kullanıcının bildirimlerini sayfalı getirir
    /// <summary>Sayfa 1'den küçükse 1, sayfa boyutu 1–50 arasına çekilir.</summary>
    public async Task<PagedResult<NotificationDto>> HandleAsync(GetNotificationsQuery query, CancellationToken cancellationToken = default)
    {
        var page = Math.Max(1, query.Page);
        var size = Math.Clamp(query.PageSize, 1, 50);
        var (items, total) = await notifications.ListAsync(query.UserId, page, size, cancellationToken);
        var dtos = items.Select(n => new NotificationDto(n.Id, n.Type, n.Title, n.Body, n.ListingId, n.OfferId, n.ReadAt is not null, n.CreatedAt)).ToList();
        return new PagedResult<NotificationDto>(dtos, page, size, total);
    }
}

/// <summary>Okunmamış bildirim sayısı (zil rozeti).</summary>
public sealed class GetUnreadNotificationCountHandler(INotificationRepository notifications)
    : IQueryHandler<GetUnreadNotificationCountQuery, UnreadNotificationCountDto>
{
    /// <summary>Tek COUNT sorgusu (UserId + ReadAt indeksi).</summary>
    public async Task<UnreadNotificationCountDto> HandleAsync(GetUnreadNotificationCountQuery query, CancellationToken cancellationToken = default) =>
        new(await notifications.CountUnreadAsync(query.UserId, cancellationToken));
}

/// <summary>Tek bildirimi okundu yapar. Başkasının/olmayan bildirim 404 (varlığı sızdırılmaz); zaten okunduysa sessizce başarılı.</summary>
public sealed class MarkNotificationReadHandler(INotificationRepository notifications, TimeProvider time)
    : ICommandHandler<MarkNotificationReadCommand, bool>
{
    /// <summary>NotFoundException (404): bildirim yok ya da başkasının.</summary>
    public async Task<bool> HandleAsync(MarkNotificationReadCommand command, CancellationToken cancellationToken = default)
    {
        var found = await notifications.MarkReadAsync(command.UserId, command.NotificationId, time.GetUtcNow().UtcDateTime, cancellationToken);
        return found ? true : throw new NotFoundException("Bildirim bulunamadı.");
    }
}

/// <summary>Okunmamış bildirimlerin hepsini okundu yapar. Kaç tane değiştiğini döner.</summary>
public sealed class MarkAllNotificationsReadHandler(INotificationRepository notifications, TimeProvider time)
    : ICommandHandler<MarkAllNotificationsReadCommand, int>
{
    /// <summary>Okunmamış yoksa 0 döner, hata vermez.</summary>
    public Task<int> HandleAsync(MarkAllNotificationsReadCommand command, CancellationToken cancellationToken = default) =>
        notifications.MarkAllReadAsync(command.UserId, time.GetUtcNow().UtcDateTime, cancellationToken);
}

/// <summary>
/// Tek bildirimi siler. Okundu'dan FARKI: yoksa/başkasınınsa da başarılı döner (404 yok).
/// NEDEN: silmenin amacı "bu bildirim listemde olmasın"; zaten yoksa amaç gerçekleşmiştir. İstemci aynı isteği iki kez gönderse
/// (zayıf bağlantıda tekrar) hata görmez. Başkasının bildirimi için de aynı cevap döndüğünden varlığı sızmaz, satıra da dokunulmaz.
/// </summary>
public sealed class DeleteNotificationHandler(INotificationRepository notifications)
    : ICommandHandler<DeleteNotificationCommand, bool>
{
    /// <summary>true: bir satır silindi | false: silinecek bir şey yoktu. İkisi de hata değildir.</summary>
    public async Task<bool> HandleAsync(DeleteNotificationCommand command, CancellationToken cancellationToken = default) =>
        await notifications.DeleteAsync(command.UserId, command.NotificationId, cancellationToken) > 0;
}
