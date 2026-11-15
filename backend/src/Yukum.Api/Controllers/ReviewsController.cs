using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Reviews;
using Yukum.Domain.Accounts;

namespace Yukum.Api.Controllers;

/// <summary>Puan ve profil uçları. Yük Veren tamamlanmış işi puanlar; herkes (giriş yapmış) Taşımacı profilini görür.</summary>
[ApiController]
[ApiVersion("1.0")]
public class ReviewsController(
    ICommandHandler<CreateReviewCommand, ReviewDto> createReview,
    IQueryHandler<GetCarrierProfileQuery, CarrierProfileDto> getProfile,
    IQueryHandler<GetShipperProfileQuery, ShipperProfileDto> getShipperProfile) : ControllerBase
{
    /// <summary>Yük Veren tamamlanmış işi puanlar (1–5 + yorum). Her işe bir kez.</summary>
    // POST /api/v1/offers/{offerId}/review
    // FONKSİYON ROLÜ: API'NİN KAPISI | iOS'taki ReviewService.create'in isteğini karşılar, rolü kontrol eder, işi CreateReviewHandler'a devreder
    [HttpPost("api/v{version:apiVersion}/offers/{offerId:guid}/review")]
    [Authorize(Roles = RoleNames.Shipper)]
    [ProducesResponseType<ReviewDto>(StatusCodes.Status201Created)]
    public async Task<IActionResult> Create(Guid offerId, CreateReviewRequest request, CancellationToken cancellationToken)
    {
        var command = new CreateReviewCommand(offerId, CurrentUserId, request.Rating, request.Comment);
        return StatusCode(StatusCodes.Status201Created, await createReview.HandleAsync(command, cancellationToken));
    }

    /// <summary>Taşımacı profili: ortalama puan, tamamlanan iş, son yorumlar.</summary>
    // GET /api/v1/carriers/{carrierId}
    [HttpGet("api/v{version:apiVersion}/carriers/{carrierId:guid}")]
    [Authorize] // giriş yapmış herkes (iki rol de)
    [ProducesResponseType<CarrierProfileDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Profile(Guid carrierId, CancellationToken cancellationToken) =>
        Ok(await getProfile.HandleAsync(new GetCarrierProfileQuery(carrierId), cancellationToken));

    /// <summary>Yük Veren profili (15 Kasım, 8. adım): ad, fotoğraf, firma, il, hakkında, üyelik, ilan sayıları. Telefon/e-posta/vergi bilgisi YOK.</summary>
    // GET /api/v1/shippers/{shipperId} → 200 ShipperProfileDto | 404 (Yük Veren değil / silinmiş)
    // ZİNCİR: iOS ListingDetailView "Yük Veren" satırı → ShipperProfileView → ReviewService.shipperProfile → burası → GetShipperProfileHandler
    [HttpGet("api/v{version:apiVersion}/shippers/{shipperId:guid}")]
    [Authorize] // giriş yapmış herkes (iki rol de)
    [ProducesResponseType<ShipperProfileDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ShipperProfile(Guid shipperId, CancellationToken cancellationToken) =>
        Ok(await getShipperProfile.HandleAsync(new GetShipperProfileQuery(shipperId), cancellationToken));

    // Jetondaki 'sub' (kullanıcı numarası).
    private Guid CurrentUserId => Guid.Parse(User.FindFirst("sub")!.Value);
}
