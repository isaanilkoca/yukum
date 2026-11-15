using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Accounts;

namespace Yukum.Api.Controllers;

/// <summary>Engelle ve şikâyet et (iki rol de kullanır). Akış haritası: Application/Accounts/SafetyContracts.cs.</summary>
[ApiController]
[ApiVersion("1.0")]
[Authorize]
public class SafetyController(
    ICommandHandler<BlockUserCommand, bool> block,
    IQueryHandler<GetBlockedUsersQuery, IReadOnlyList<BlockedUserDto>> getBlocked,
    ICommandHandler<ReportUserCommand, bool> report) : ControllerBase
{
    /// <summary>Kullanıcıyı engeller. Zaten engelliyse de 204 (idempotent).</summary>
    // PUT /api/v1/users/{userId}/block
    [HttpPut("api/v{version:apiVersion}/users/{userId:guid}/block")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Block(Guid userId, CancellationToken cancellationToken)
    {
        await block.HandleAsync(new BlockUserCommand(CurrentUserId, userId, true), cancellationToken);
        return NoContent();
    }

    /// <summary>Engeli kaldırır. Engelli değilse de 204 (idempotent).</summary>
    // DELETE /api/v1/users/{userId}/block
    [HttpDelete("api/v{version:apiVersion}/users/{userId:guid}/block")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Unblock(Guid userId, CancellationToken cancellationToken)
    {
        await block.HandleAsync(new BlockUserCommand(CurrentUserId, userId, false), cancellationToken);
        return NoContent();
    }

    /// <summary>Engellediğim kişiler (Profil → Engellediklerim).</summary>
    // GET /api/v1/account/blocks
    [HttpGet("api/v{version:apiVersion}/account/blocks")]
    [ProducesResponseType<IReadOnlyList<BlockedUserDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Blocked(CancellationToken cancellationToken) =>
        Ok(await getBlocked.HandleAsync(new GetBlockedUsersQuery(CurrentUserId), cancellationToken));

    /// <summary>Kullanıcıyı şikâyet eder. 24 saat içinde aynı kişiye ikinci şikâyet yeni kayıt açmaz (yine 204).</summary>
    // POST /api/v1/users/{userId}/report   gövde: { reason: "Fraud", note?, listingId?, offerId? }
    [HttpPost("api/v{version:apiVersion}/users/{userId:guid}/report")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Report(Guid userId, ReportUserRequest request, CancellationToken cancellationToken)
    {
        await report.HandleAsync(new ReportUserCommand(CurrentUserId, userId, request.Reason, request.Note, request.ListingId, request.OfferId), cancellationToken);
        return NoContent();
    }

    // Jetondaki 'sub' (kullanıcı numarası).
    private Guid CurrentUserId => Guid.Parse(User.FindFirst("sub")!.Value);
}
