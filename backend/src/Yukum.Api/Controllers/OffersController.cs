using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Offers;
using Yukum.Domain.Accounts;

namespace Yukum.Api.Controllers;

/// <summary>Teklif uçları. Taşımacı: teklif ver. Yük Veren: ilanına gelen teklifleri gör, kabul/reddet.</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/listings/{listingId:guid}/offers")]
public class OffersController(
    ICommandHandler<CreateOfferCommand, OfferDto> createOffer,
    IQueryHandler<GetListingOffersQuery, IReadOnlyList<ListingOfferDto>> getListingOffers,
    ICommandHandler<DecideOfferCommand, OfferDto> decideOffer,
    IQueryHandler<GetMyOffersQuery, IReadOnlyList<CarrierOfferDto>> getMyOffers,
    IQueryHandler<GetShipperOfferHistoryQuery, IReadOnlyList<ShipperOfferHistoryDto>> getShipperHistory,
    ICommandHandler<HideOfferCommand, bool> hideOffer,
    IQueryHandler<GetUnseenCountQuery, UnseenCountDto> getUnseenCount,
    ICommandHandler<MarkSeenCommand, bool> markSeen,
    ICommandHandler<CompleteOfferCommand, OfferDto> completeOffer) : ControllerBase
{
    /// <summary>İlana teklif verir; aynı ilana tekrar verilirse eski teklifin tutarı güncellenir.</summary>
    // POST /api/v1/listings/{listingId}/offers
    // FONKSİYON ROLÜ: API'NİN KAPISI | iOS'taki OfferService.create'in isteğini karşılar, rolü kontrol eder, işi CreateOfferHandler'a devredip cevabı döner
    [HttpPost]
    [Authorize(Roles = RoleNames.Carrier)] // yalnız Taşımacı; değilse 403, jeton yoksa 401
    [ProducesResponseType<OfferDto>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create(Guid listingId, CreateOfferRequest request, CancellationToken cancellationToken)
    {
        var command = new CreateOfferCommand(listingId, CurrentUserId, request.Amount, request.Note);
        return Ok(await createOffer.HandleAsync(command, cancellationToken));
    }

    /// <summary>İlan sahibi Yük Veren, ilanına gelen teklifleri görür (düşük tutar üstte).</summary>
    // GET /api/v1/listings/{listingId}/offers
    [HttpGet]
    [Authorize(Roles = RoleNames.Shipper)]
    [ProducesResponseType<IReadOnlyList<ListingOfferDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> ForListing(Guid listingId, CancellationToken cancellationToken) =>
        Ok(await getListingOffers.HandleAsync(new GetListingOffersQuery(listingId, CurrentUserId), cancellationToken));

    /// <summary>Teklifi kabul eder: ilan atanır, diğer bekleyen teklifler reddedilir.</summary>
    // POST /api/v1/offers/{offerId}/accept  (~ = sınıfın ortak adresini kullanma, tam adres)
    [HttpPost("~/api/v{version:apiVersion}/offers/{offerId:guid}/accept")]
    [Authorize(Roles = RoleNames.Shipper)]
    [ProducesResponseType<OfferDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Accept(Guid offerId, CancellationToken cancellationToken) =>
        Ok(await decideOffer.HandleAsync(new DecideOfferCommand(offerId, CurrentUserId, true), cancellationToken));

    /// <summary>Teklifi reddeder.</summary>
    // POST /api/v1/offers/{offerId}/reject
    [HttpPost("~/api/v{version:apiVersion}/offers/{offerId:guid}/reject")]
    [Authorize(Roles = RoleNames.Shipper)]
    [ProducesResponseType<OfferDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Reject(Guid offerId, CancellationToken cancellationToken) =>
        Ok(await decideOffer.HandleAsync(new DecideOfferCommand(offerId, CurrentUserId, false), cancellationToken));

    /// <summary>Taşımacı'nın tüm teklifleri (bekleyen, kabul, red) = "Tekliflerim / eski teklifler".</summary>
    // GET /api/v1/offers/mine
    [HttpGet("~/api/v{version:apiVersion}/offers/mine")]
    [Authorize(Roles = RoleNames.Carrier)]
    [ProducesResponseType<IReadOnlyList<CarrierOfferDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> MyOffers(CancellationToken cancellationToken) =>
        Ok(await getMyOffers.HandleAsync(new GetMyOffersQuery(CurrentUserId), cancellationToken));

    /// <summary>Taşımacı'nın görmediği karar sayısı (bildirim rozeti).</summary>
    // GET /api/v1/offers/mine/unseen-count
    [HttpGet("~/api/v{version:apiVersion}/offers/mine/unseen-count")]
    [Authorize(Roles = RoleNames.Carrier)]
    [ProducesResponseType<UnseenCountDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> UnseenCount(CancellationToken cancellationToken) =>
        Ok(await getUnseenCount.HandleAsync(new GetUnseenCountQuery(CurrentUserId), cancellationToken));

    /// <summary>Taşımacı karar bildirimlerini görüldü işaretler.</summary>
    // POST /api/v1/offers/mine/seen
    [HttpPost("~/api/v{version:apiVersion}/offers/mine/seen")]
    [Authorize(Roles = RoleNames.Carrier)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> MarkSeen(CancellationToken cancellationToken)
    {
        await markSeen.HandleAsync(new MarkSeenCommand(CurrentUserId), cancellationToken);
        return NoContent();
    }

    /// <summary>Yük Veren'in karara bağladığı (kabul/red) tekliflerin geçmişi = "eski teklifler".</summary>
    // GET /api/v1/offers/history
    [HttpGet("~/api/v{version:apiVersion}/offers/history")]
    [Authorize(Roles = RoleNames.Shipper)]
    [ProducesResponseType<IReadOnlyList<ShipperOfferHistoryDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> ShipperHistory(CancellationToken cancellationToken) =>
        Ok(await getShipperHistory.HandleAsync(new GetShipperOfferHistoryQuery(CurrentUserId), cancellationToken));

    /// <summary>Karara bağlanmış teklifi kullanıcının kendi geçmişinden siler (karşı taraf görmeye devam eder).</summary>
    // DELETE /api/v1/offers/{offerId}
    [HttpDelete("~/api/v{version:apiVersion}/offers/{offerId:guid}")]
    [Authorize(Roles = $"{RoleNames.Shipper},{RoleNames.Carrier}")] // iki rol de silebilir, her biri yalnız kendi tarafını
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Hide(Guid offerId, CancellationToken cancellationToken)
    {
        await hideOffer.HandleAsync(new HideOfferCommand(offerId, CurrentUserId, User.IsInRole(RoleNames.Carrier)), cancellationToken);
        return NoContent();
    }

    /// <summary>"İşi bitir ve sil": kabul edilmiş işi tamamlar. Teklif iki tarafta Tamamlandı olur, sohbet iki tarafta kilitlenir; bitirenin geçmişinden silinir.</summary>
    // POST /api/v1/offers/{offerId}/complete
    [HttpPost("~/api/v{version:apiVersion}/offers/{offerId:guid}/complete")]
    [Authorize(Roles = $"{RoleNames.Shipper},{RoleNames.Carrier}")] // iki taraf da bitirebilir
    [ProducesResponseType<OfferDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Complete(Guid offerId, CancellationToken cancellationToken) =>
        Ok(await completeOffer.HandleAsync(new CompleteOfferCommand(offerId, CurrentUserId), cancellationToken));

    // Jetondaki 'sub' (kullanıcı numarası).
    private Guid CurrentUserId => Guid.Parse(User.FindFirst("sub")!.Value);
}
