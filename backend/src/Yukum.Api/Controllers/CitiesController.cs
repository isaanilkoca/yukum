using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Geography;

namespace Yukum.Api.Controllers;

/// <summary>
/// İl ve ilçe listeleri. Herkese açıktır (kayıt ekranında giriş yapmadan da kullanılır) ve veri nadiren
/// değiştiği için istemcilerin 1 gün önbelleğe almasına izin verilir.
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/cities")]
[AllowAnonymous]
[ResponseCache(Duration = 86400, Location = ResponseCacheLocation.Any)]
public class CitiesController(
    IQueryHandler<GetCitiesQuery, IReadOnlyList<CityDto>> getCities,
    IQueryHandler<GetDistrictsQuery, IReadOnlyList<DistrictDto>> getDistricts) : ControllerBase
{
    /// <summary>81 ilin listesi (plaka koduna göre sıralı).</summary>
    /// <param name="cancellationToken">İstemci isteği iptal ederse işlem de durur.</param>
    /// <returns>İl listesi: <c>id</c> plaka kodudur, <c>name</c> ilin adıdır.</returns>
    [HttpGet]
    [ProducesResponseType<IReadOnlyList<CityDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetCities(CancellationToken cancellationToken) =>
        Ok(await getCities.HandleAsync(new GetCitiesQuery(), cancellationToken));

    /// <summary>Bir ilin ilçelerinin listesi (Türkçe alfabetik sıralı).</summary>
    /// <param name="cityId">İlin plaka kodu (1–81).</param>
    /// <param name="cancellationToken">İstemci isteği iptal ederse işlem de durur.</param>
    /// <returns>İlçe listesi. İl yoksa 404 (ProblemDetails).</returns>
    [HttpGet("{cityId:int}/districts")]
    [ProducesResponseType<IReadOnlyList<DistrictDto>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetDistricts(int cityId, CancellationToken cancellationToken) =>
        Ok(await getDistricts.HandleAsync(new GetDistrictsQuery(cityId), cancellationToken));
}
