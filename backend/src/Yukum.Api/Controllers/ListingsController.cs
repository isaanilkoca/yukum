using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Listings;
using Yukum.Domain.Accounts;

namespace Yukum.Api.Controllers;

/// <summary>İlan uçları. Şimdilik yalnız Yük Veren: ilan aç ve kendi ilanlarını listele.</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/listings")]
// Rol kontrolü her uçta ayrı (aşağıda): sınıf düzeyinde yazılsaydı iki rol de aynı anda sağlanmak zorunda kalırdı.
public class ListingsController(
    ICommandHandler<CreateListingCommand, ListingDto> createListing,
    IQueryHandler<GetMyListingsQuery, IReadOnlyList<ListingDto>> getMyListings,
    IQueryHandler<GetOpenListingsQuery, IReadOnlyList<ListingDto>> getOpenListings) : ControllerBase
{
    /// <summary>Yeni ilan açar. İlan sahibi istekten değil jetondan alınır.</summary>
    // POST /api/v1/listings
    [HttpPost]
    [Authorize(Roles = RoleNames.Shipper)] // yalnız Yük Veren; değilse 403, jeton yoksa 401
    [ProducesResponseType<ListingDto>(StatusCodes.Status201Created)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create(CreateListingRequest request, CancellationToken cancellationToken)
    {
        var command = new CreateListingCommand(CurrentUserId, request.Title, request.Description, request.WeightKg,
            request.VehicleType, request.FromCityId, request.FromDistrictId, request.ToCityId, request.ToDistrictId,
            request.PickupDate, request.Budget);
        var created = await createListing.HandleAsync(command, cancellationToken);
        return StatusCode(StatusCodes.Status201Created, created);
    }

    /// <summary>Giriş yapan Yük Veren'in kendi ilanları (yeniden eskiye).</summary>
    // GET /api/v1/listings/mine
    [HttpGet("mine")]
    [Authorize(Roles = RoleNames.Shipper)]
    [ProducesResponseType<IReadOnlyList<ListingDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Mine(CancellationToken cancellationToken) =>
        Ok(await getMyListings.HandleAsync(new GetMyListingsQuery(CurrentUserId), cancellationToken));

    /// <summary>Tüm açık ilanlar (yeniden eskiye). Yalnız Taşımacı görür.</summary>
    // GET /api/v1/listings
    [HttpGet]
    [Authorize(Roles = RoleNames.Carrier)]
    [ProducesResponseType<IReadOnlyList<ListingDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Open(CancellationToken cancellationToken) =>
        Ok(await getOpenListings.HandleAsync(new GetOpenListingsQuery(), cancellationToken));

    // Jetondaki 'sub' (kullanıcı numarası). MapInboundClaims kapalı olduğu için adı 'sub'dır.
    private Guid CurrentUserId => Guid.Parse(User.FindFirst("sub")!.Value);
}
