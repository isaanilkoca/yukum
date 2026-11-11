using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Common;
using Yukum.Application.Notifications;

namespace Yukum.Api.Controllers;

/// <summary>Uygulama içi bildirimler: liste, okunmamış sayısı, okundu işaretleme. Her giriş yapmış kullanıcı (iki rol) yalnız KENDİ bildirimlerini görür.</summary>
[ApiController]
[ApiVersion("1.0")]
[Authorize]
public class NotificationsController(
    IQueryHandler<GetNotificationsQuery, PagedResult<NotificationDto>> list,
    IQueryHandler<GetUnreadNotificationCountQuery, UnreadNotificationCountDto> unread,
    ICommandHandler<MarkNotificationReadCommand, bool> markRead,
    ICommandHandler<MarkAllNotificationsReadCommand, int> markAllRead) : ControllerBase
{
    /// <summary>Bildirimlerim, en yeni üstte (sayfalı).</summary>
    // GET /api/v1/notifications?page=1&pageSize=20
    // FONKSİYON ROLÜ: API'NİN KAPISI | iOS'taki bildirim listesinin isteğini karşılar
    [HttpGet("api/v{version:apiVersion}/notifications")]
    [ProducesResponseType<PagedResult<NotificationDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> List([FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken cancellationToken = default) =>
        Ok(await list.HandleAsync(new GetNotificationsQuery(CurrentUserId, page, pageSize), cancellationToken));

    /// <summary>Okunmamış bildirim sayısı (zil rozeti).</summary>
    // GET /api/v1/notifications/unread-count
    [HttpGet("api/v{version:apiVersion}/notifications/unread-count")]
    [ProducesResponseType<UnreadNotificationCountDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> UnreadCount(CancellationToken cancellationToken) =>
        Ok(await unread.HandleAsync(new GetUnreadNotificationCountQuery(CurrentUserId), cancellationToken));

    /// <summary>Bildirimi okundu yapar. Zaten okunduysa da 204 (idempotent); başkasının/olmayan 404.</summary>
    // POST /api/v1/notifications/{id}/read
    [HttpPost("api/v{version:apiVersion}/notifications/{id:guid}/read")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Read(Guid id, CancellationToken cancellationToken)
    {
        await markRead.HandleAsync(new MarkNotificationReadCommand(CurrentUserId, id), cancellationToken);
        return NoContent();
    }

    /// <summary>Okunmamışların hepsini okundu yapar.</summary>
    // POST /api/v1/notifications/read-all
    [HttpPost("api/v{version:apiVersion}/notifications/read-all")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> ReadAll(CancellationToken cancellationToken)
    {
        await markAllRead.HandleAsync(new MarkAllNotificationsReadCommand(CurrentUserId), cancellationToken);
        return NoContent();
    }

    // Jetondaki 'sub' (kullanıcı numarası).
    private Guid CurrentUserId => Guid.Parse(User.FindFirst("sub")!.Value);
}
