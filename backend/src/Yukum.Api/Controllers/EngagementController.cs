using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Engagement;
using Yukum.Application.Listings;
using Yukum.Domain.Accounts;

namespace Yukum.Api.Controllers;

/// <summary>Favori, görüntülenme ve ilan sayıları. Taşımacı: favorile, favorilerim, detay görüntülendi. Yük Veren: kendi ilanının sayıları.</summary>
[ApiController]
[ApiVersion("1.0")]
public class EngagementController(
    ICommandHandler<SetFavoriteCommand, bool> setFavorite,
    ICommandHandler<RecordViewCommand, bool> recordView,
    IQueryHandler<GetFavoriteListingsQuery, IReadOnlyList<ListingDto>> getFavorites,
    IQueryHandler<GetListingStatsQuery, ListingStatsDto> getStats) : ControllerBase
{
    /// <summary>İlanı favoriler. Zaten favoriyse de başarılıdır (idempotent).</summary>
    // PUT /api/v1/listings/{listingId}/favorite
    // FONKSİYON ROLÜ: API'NİN KAPISI | iOS'taki favori düğmesinin isteğini karşılar | PUT: "bu kaynak şu durumda olsun" (tekrar çağırmak sonucu değiştirmez)
    [HttpPut("api/v{version:apiVersion}/listings/{listingId:guid}/favorite")]
    [Authorize(Roles = RoleNames.Carrier)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> AddFavorite(Guid listingId, CancellationToken cancellationToken)
    {
        await setFavorite.HandleAsync(new SetFavoriteCommand(CurrentUserId, listingId, true), cancellationToken);
        return NoContent();
    }

    /// <summary>İlanı favoriden çıkarır. Favori değilse de başarılıdır (idempotent).</summary>
    // DELETE /api/v1/listings/{listingId}/favorite
    [HttpDelete("api/v{version:apiVersion}/listings/{listingId:guid}/favorite")]
    [Authorize(Roles = RoleNames.Carrier)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> RemoveFavorite(Guid listingId, CancellationToken cancellationToken)
    {
        await setFavorite.HandleAsync(new SetFavoriteCommand(CurrentUserId, listingId, false), cancellationToken);
        return NoContent();
    }

    /// <summary>Taşımacı'nın favori ve hâlâ açık ilanları (son favorilenen üstte).</summary>
    // GET /api/v1/listings/favorites
    [HttpGet("api/v{version:apiVersion}/listings/favorites")]
    [Authorize(Roles = RoleNames.Carrier)]
    [ProducesResponseType<IReadOnlyList<ListingDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Favorites(CancellationToken cancellationToken) =>
        Ok(await getFavorites.HandleAsync(new GetFavoriteListingsQuery(CurrentUserId), cancellationToken));

    /// <summary>İlan detayı açıldı: görüntülenme yazılır (aynı kişi aynı gün tek sayılır).</summary>
    // POST /api/v1/listings/{listingId}/view
    [HttpPost("api/v{version:apiVersion}/listings/{listingId:guid}/view")]
    [Authorize(Roles = RoleNames.Carrier)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> View(Guid listingId, CancellationToken cancellationToken)
    {
        await recordView.HandleAsync(new RecordViewCommand(CurrentUserId, listingId), cancellationToken);
        return NoContent();
    }

    /// <summary>İlan sahibi: görüntülenme, favori ve teklif sayıları.</summary>
    // GET /api/v1/listings/{listingId}/stats
    [HttpGet("api/v{version:apiVersion}/listings/{listingId:guid}/stats")]
    [Authorize(Roles = RoleNames.Shipper)]
    [ProducesResponseType<ListingStatsDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Stats(Guid listingId, CancellationToken cancellationToken) =>
        Ok(await getStats.HandleAsync(new GetListingStatsQuery(listingId, CurrentUserId), cancellationToken));

    // Jetondaki 'sub' (kullanıcı numarası).
    private Guid CurrentUserId => Guid.Parse(User.FindFirst("sub")!.Value);
}
