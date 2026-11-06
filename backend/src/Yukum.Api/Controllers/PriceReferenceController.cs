using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.PriceReference;
using Yukum.Domain.Accounts;

namespace Yukum.Api.Controllers;

/// <summary>Emsal fiyat ucu: "bu rotada tipik fiyat ₺X" göstergesi için.</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/price-reference")]
[Authorize] // giriş yapmış herkes
public class PriceReferenceController(IQueryHandler<GetPriceReferenceQuery, PriceReferenceDto> getPriceReference) : ControllerBase
{
    /// <summary>Aynı kalkış ili, varış ili ve araç tipi için son 180 günde tamamlanan işlerin medyan tutarı (en az 3 iş yoksa boş).</summary>
    // GET /api/v1/price-reference?fromCityId=33&toCityId=34&vehicleType=Truck
    // FONKSİYON ROLÜ: API'NİN KAPISI | iOS'taki ListingService.priceReference'ın isteğini karşılar, parametreleri denetler, işi GetPriceReferenceHandler'a devreder
    [HttpGet]
    [ProducesResponseType<PriceReferenceDto>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Get(int fromCityId, int toCityId, VehicleType vehicleType, CancellationToken cancellationToken)
    {
        if (fromCityId <= 0 || toCityId <= 0 || !Enum.IsDefined(vehicleType))
            return Problem(statusCode: StatusCodes.Status400BadRequest, title: "Geçersiz istek",
                detail: "fromCityId, toCityId ve geçerli bir vehicleType gerekli.");
        return Ok(await getPriceReference.HandleAsync(new GetPriceReferenceQuery(fromCityId, toCityId, vehicleType), cancellationToken));
    }
}
