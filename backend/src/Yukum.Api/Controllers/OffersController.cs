using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Offers;
using Yukum.Domain.Accounts;

namespace Yukum.Api.Controllers;

/// <summary>Teklif uçları. Şimdilik yalnız Taşımacı: bir ilana teklif ver.</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/listings/{listingId:guid}/offers")]
public class OffersController(ICommandHandler<CreateOfferCommand, OfferDto> createOffer) : ControllerBase
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

    // Jetondaki 'sub' (kullanıcı numarası).
    private Guid CurrentUserId => Guid.Parse(User.FindFirst("sub")!.Value);
}
