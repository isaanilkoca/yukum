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

    /// <summary>Tüm açık ilanlar (yeniden eskiye). Yalnız Taşımacı görür. İsteğe bağlı filtre: kalkış ili ve ilçesi.</summary>
    // GET /api/v1/listings
    [HttpGet]
    [Authorize(Roles = RoleNames.Carrier)]
    [ProducesResponseType<IReadOnlyList<ListingDto>>(StatusCodes.Status200OK)]
    // GET /api/v1/listings?fromCityId=33&fromDistrictId=12&lat=36.8&lon=34.6  (hepsi isteğe bağlı; query string = adresteki ?...&... kısmı)
    // lat+lon verilirse ilanlar en yakından uzağa sıralanır ve her ilanda distanceKm döner. Konum kaydedilmez, yalnız bu istekte kullanılır.
    public async Task<IActionResult> Open(int? fromCityId, int? fromDistrictId, double? lat, double? lon, CancellationToken cancellationToken)
    {
        // Konum ya iki parça birlikte (lat ve lon) ya hiç; geçerli aralıkta olmalı (enlem -90..90, boylam -180..180).
        if ((lat is null) != (lon is null) || lat is < -90 or > 90 || lon is < -180 or > 180)
        {
            ModelState.AddModelError("location", "lat ve lon birlikte, geçerli aralıkta verilmeli.");
            return ValidationProblem(ModelState);
        }
        return Ok(await getOpenListings.HandleAsync(new GetOpenListingsQuery(CurrentUserId, fromCityId, fromDistrictId, lat, lon), cancellationToken));
    }

    // Jetondaki 'sub' (kullanıcı numarası). MapInboundClaims kapalı olduğu için adı 'sub'dır.
    private Guid CurrentUserId => Guid.Parse(User.FindFirst("sub")!.Value);
}
