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
// [ApiController]: bu sınıf bir API ucudur (JSON ↔ C# dönüşümü ve otomatik 400 doğrulaması).
[ApiController]
// Bu controller API sürüm 1.0'a aittir.
[ApiVersion("1.0")]
// Adres: /api/v1/cities...
[Route("api/v{version:apiVersion}/cities")]
// Giriş gerekmez: kayıt ekranında kullanıcı henüz giriş yapmamıştır ama il seçmesi gerekir.
[AllowAnonymous]
// İstemci ve aradaki katmanlar bu cevabı 1 gün (86400 sn) saklayabilir: 'Cache-Control: public,max-age=86400'. Hata (404) cevaplarına uygulanmaz.
[ResponseCache(Duration = 86400, Location = ResponseCacheLocation.Any)]
// İki handler enjekte edilir: il listesi ve ilçe listesi. Controller yalnız yönlendirir.
public class CitiesController(
    IQueryHandler<GetCitiesQuery, IReadOnlyList<CityDto>> getCities,
    IQueryHandler<GetDistrictsQuery, IReadOnlyList<DistrictDto>> getDistricts) : ControllerBase
{
    /// <summary>81 ilin listesi (plaka koduna göre sıralı).</summary>
    /// <param name="cancellationToken">İstemci isteği iptal ederse işlem de durur.</param>
    /// <returns>İl listesi: <c>id</c> plaka kodudur, <c>name</c> ilin adıdır.</returns>
    // GET /api/v1/cities
    [HttpGet]
    [ProducesResponseType<IReadOnlyList<CityDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetCities(CancellationToken cancellationToken) =>
        // 200 OK + 81 il. 'new GetCitiesQuery()': parametresiz sorgu nesnesi.
        Ok(await getCities.HandleAsync(new GetCitiesQuery(), cancellationToken));

    /// <summary>Bir ilin ilçelerinin listesi (Türkçe alfabetik sıralı).</summary>
    /// <param name="cityId">İlin plaka kodu (1–81).</param>
    /// <param name="cancellationToken">İstemci isteği iptal ederse işlem de durur.</param>
    /// <returns>İlçe listesi. İl yoksa 404 (ProblemDetails).</returns>
    // GET /api/v1/cities/42/districts. ':int' kuralı: sayı olmayan (abc) adres bu uca hiç eşleşmez, 404 olur.
    [HttpGet("{cityId:int}/districts")]
    [ProducesResponseType<IReadOnlyList<DistrictDto>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetDistricts(int cityId, CancellationToken cancellationToken) =>
        // İl yoksa handler NotFoundException fırlatır → GlobalExceptionHandler 404 cevabı üretir.
        Ok(await getDistricts.HandleAsync(new GetDistrictsQuery(cityId), cancellationToken));
}
