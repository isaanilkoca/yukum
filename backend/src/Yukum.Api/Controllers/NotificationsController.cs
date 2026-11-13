using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Common;
using Yukum.Application.Notifications;

namespace Yukum.Api.Controllers;

/// <summary>Uygulama içi bildirimler: liste, okunmamış sayısı, okundu işaretleme, silme. Her giriş yapmış kullanıcı (iki rol) yalnız KENDİ bildirimlerini görür.</summary>
[ApiController]
[ApiVersion("1.0")]
[Authorize]
public class NotificationsController(
    IQueryHandler<GetNotificationsQuery, PagedResult<NotificationDto>> list,
    IQueryHandler<GetUnreadNotificationCountQuery, UnreadNotificationCountDto> unread,
    ICommandHandler<MarkNotificationReadCommand, bool> markRead,
    ICommandHandler<MarkAllNotificationsReadCommand, int> markAllRead,
    ICommandHandler<DeleteNotificationCommand, bool> delete,
    ICommandHandler<RegisterDeviceTokenCommand, bool> registerDevice,
    ICommandHandler<RemoveDeviceTokenCommand, bool> removeDevice) : ControllerBase
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

    /// <summary>Bildirimi kalıcı siler. Yoksa ya da başkasınınsa da 204 (idempotent, varlık sızdırılmaz); başkasının bildirimine dokunulmaz.</summary>
    // DELETE /api/v1/notifications/{id}
    // {id:guid} kısıtı sayesinde aşağıdaki "device-token" adresiyle karışmaz: "device-token" bir GUID değildir, bu uca düşmez.
    [HttpDelete("api/v{version:apiVersion}/notifications/{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        await delete.HandleAsync(new DeleteNotificationCommand(CurrentUserId, id), cancellationToken);
        return NoContent();
    }

    /// <summary>Telefonun push adresini (APNs cihaz jetonu) kaydeder. Tekrar çağrılabilir; her uygulama açılışında gönderilir.</summary>
    // PUT /api/v1/notifications/device-token  gövde: { "token": "<onaltılık>", "deviceId": "...", "sandbox": true }
    // PUT: "bu cihazın adresi şu olsun" (tekrar çağırmak sonucu değiştirmez)
    [HttpPut("api/v{version:apiVersion}/notifications/device-token")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> RegisterDevice(RegisterDeviceTokenRequest request, CancellationToken cancellationToken)
    {
        await registerDevice.HandleAsync(new RegisterDeviceTokenCommand(CurrentUserId, request.DeviceId, request.Token, request.Sandbox), cancellationToken);
        return NoContent();
    }

    /// <summary>Bu cihazın push adresini siler (çıkış yapmadan hemen önce çağrılır). Kayıt yoksa da 204.</summary>
    // DELETE /api/v1/notifications/device-token?deviceId=...
    [HttpDelete("api/v{version:apiVersion}/notifications/device-token")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> RemoveDevice([FromQuery] string? deviceId, CancellationToken cancellationToken)
    {
        await removeDevice.HandleAsync(new RemoveDeviceTokenCommand(CurrentUserId, deviceId), cancellationToken);
        return NoContent();
    }

    // Jetondaki 'sub' (kullanıcı numarası).
    private Guid CurrentUserId => Guid.Parse(User.FindFirst("sub")!.Value);
}

/// <summary>Cihaz jetonu kayıt isteğinin gövdesi. Kullanıcı numarası gövdeden değil jetondan (JWT) alınır.</summary>
public sealed record RegisterDeviceTokenRequest(string? Token, string? DeviceId, bool Sandbox);
