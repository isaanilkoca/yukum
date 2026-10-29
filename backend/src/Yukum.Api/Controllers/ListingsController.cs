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
// Jetondaki 'role' Shipper olmalı; değilse 403, jeton yoksa 401.
[Authorize(Roles = RoleNames.Shipper)]
public class ListingsController(
    ICommandHandler<CreateListingCommand, ListingDto> createListing,
    IQueryHandler<GetMyListingsQuery, IReadOnlyList<ListingDto>> getMyListings) : ControllerBase
{
    /// <summary>Yeni ilan açar. İlan sahibi istekten değil jetondan alınır.</summary>
    // POST /api/v1/listings
    [HttpPost]
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
    [ProducesResponseType<IReadOnlyList<ListingDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Mine(CancellationToken cancellationToken) =>
        Ok(await getMyListings.HandleAsync(new GetMyListingsQuery(CurrentUserId), cancellationToken));

    // Jetondaki 'sub' (kullanıcı numarası). MapInboundClaims kapalı olduğu için adı 'sub'dır.
    private Guid CurrentUserId => Guid.Parse(User.FindFirst("sub")!.Value);
}
