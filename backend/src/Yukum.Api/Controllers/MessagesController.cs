using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Messages;
using Yukum.Domain.Accounts;

namespace Yukum.Api.Controllers;

/// <summary>Teklif sohbeti: ilan sahibi ile teklifi veren taşımacı yazışır. Başkası erişemez (404).</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/offers/{offerId:guid}/messages")]
[Authorize(Roles = $"{RoleNames.Shipper},{RoleNames.Carrier}")] // iki rol de girer; asıl yetki "bu teklifin tarafı mısın" kontrolüdür (handler)
public class MessagesController(
    IQueryHandler<GetMessagesQuery, IReadOnlyList<MessageDto>> getMessages,
    ICommandHandler<SendMessageCommand, MessageDto> sendMessage) : ControllerBase
{
    /// <summary>Sohbetin tüm mesajları (eskiden yeniye). iOS ekran açıkken kısa aralıkla tekrar çağırır.</summary>
    // GET /api/v1/offers/{offerId}/messages
    [HttpGet]
    [ProducesResponseType<IReadOnlyList<MessageDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> List(Guid offerId, CancellationToken cancellationToken) =>
        Ok(await getMessages.HandleAsync(new GetMessagesQuery(offerId, CurrentUserId), cancellationToken));

    /// <summary>Sohbete mesaj yazar. Gönderen jetondan alınır.</summary>
    // POST /api/v1/offers/{offerId}/messages  gövde: { "text": "..." }
    [HttpPost]
    [ProducesResponseType<MessageDto>(StatusCodes.Status201Created)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Send(Guid offerId, SendMessageRequest request, CancellationToken cancellationToken) =>
        StatusCode(StatusCodes.Status201Created,
            await sendMessage.HandleAsync(new SendMessageCommand(offerId, CurrentUserId, request.Text), cancellationToken));

    // Jetondaki 'sub' (kullanıcı numarası).
    private Guid CurrentUserId => Guid.Parse(User.FindFirst("sub")!.Value);
}
