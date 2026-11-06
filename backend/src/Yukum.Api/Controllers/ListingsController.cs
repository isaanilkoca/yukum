using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Common;
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
    IQueryHandler<GetOpenListingsQuery, PagedResult<ListingDto>> getOpenListings,
    ICommandHandler<CancelListingCommand, bool> cancelListing,
    ICommandHandler<UpdateListingCommand, ListingDto> updateListing) : ControllerBase
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

    /// <summary>
    /// Taşımacı'nın açık ilan listesi: sayfalı, filtreli, sıralı. Yalnız Taşımacı görür; teklif verdiği ilanlar listede çıkmaz.
    /// Tüm parametreler isteğe bağlıdır.
    /// </summary>
    // GET /api/v1/listings?fromCityId=33&fromDistrictId=12&toCityId=34&minBudget=1000&maxBudget=9000&vehicleType=Truck
    //                     &pickupFrom=2026-11-01&pickupTo=2026-11-30&sort=PriceAsc&page=1&pageSize=20&lat=36.8&lon=34.6
    // (query string = adresteki ?...&... kısmı) | cevap: { items, page, pageSize, totalCount }
    // sort: Newest (varsayılan; konum varsa Nearest) | PriceAsc | PriceDesc | Nearest (lat+lon ister). Konum kaydedilmez, yalnız bu istekte kullanılır.
    [HttpGet]
    [Authorize(Roles = RoleNames.Carrier)]
    [ProducesResponseType<PagedResult<ListingDto>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Open(
        int? fromCityId, int? fromDistrictId, int? toCityId, decimal? minBudget, decimal? maxBudget, VehicleType? vehicleType,
        DateOnly? pickupFrom, DateOnly? pickupTo, ListingSort? sort, double? lat, double? lon,
        CancellationToken cancellationToken, int page = 1, int pageSize = 20)
    {
        // Sorgu parametrelerinin sınırları (hatalar tek 400 cevabında toplanır, alan adı camelCase).
        if ((lat is null) != (lon is null) || lat is < -90 or > 90 || lon is < -180 or > 180)
            ModelState.AddModelError("location", "lat ve lon birlikte, geçerli aralıkta verilmeli.");
        if (page < 1) ModelState.AddModelError("page", "Sayfa numarası 1 veya daha büyük olmalı.");
        if (pageSize is < 1 or > MaxPageSize) ModelState.AddModelError("pageSize", $"Sayfa boyutu 1 ile {MaxPageSize} arasında olmalı.");
        if (minBudget is < 0) ModelState.AddModelError("minBudget", "En düşük fiyat negatif olamaz.");
        if (maxBudget is < 0) ModelState.AddModelError("maxBudget", "En yüksek fiyat negatif olamaz.");
        if (minBudget is not null && maxBudget is not null && minBudget > maxBudget)
            ModelState.AddModelError("minBudget", "En düşük fiyat, en yüksek fiyattan büyük olamaz.");
        if (pickupFrom is not null && pickupTo is not null && pickupFrom > pickupTo)
            ModelState.AddModelError("pickupFrom", "Başlangıç tarihi bitiş tarihinden sonra olamaz.");
        if (sort == ListingSort.Nearest && (lat is null || lon is null))
            ModelState.AddModelError("sort", "En yakın sıralaması için lat ve lon gerekir.");
        if (!ModelState.IsValid) return ValidationProblem(ModelState);

        var query = new GetOpenListingsQuery(CurrentUserId, fromCityId, fromDistrictId, lat, lon, toCityId, minBudget, maxBudget,
            vehicleType, pickupFrom, pickupTo, sort, page, pageSize);
        return Ok(await getOpenListings.HandleAsync(query, cancellationToken));
    }

    /// <summary>İlanı günceller (tam değiştirme). Yalnız sahibi ve yalnız hâlâ açık ilan; kabul edilmiş iş/tamamlanmış/kaldırılmış 409, başkasının ilanı 404.</summary>
    // PUT /api/v1/listings/{id}
    [HttpPut("{id:guid}")]
    [Authorize(Roles = RoleNames.Shipper)] // yalnız Yük Veren; ilanın sahibi mi kontrolü handler'da (değilse 404)
    [ProducesResponseType<ListingDto>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Update(Guid id, UpdateListingRequest request, CancellationToken cancellationToken)
    {
        var command = new UpdateListingCommand(id, CurrentUserId, request.Title, request.Description, request.WeightKg,
            request.VehicleType, request.FromCityId, request.FromDistrictId, request.ToCityId, request.ToDistrictId,
            request.PickupDate, request.Budget);
        return Ok(await updateListing.HandleAsync(command, cancellationToken));
    }

    /// <summary>İlanı yayından kaldırır. Bekleyen ve kabul edilmiş teklifler iptal olur, taşımacılar bilgilenir, sohbet kilitlenir.</summary>
    // POST /api/v1/listings/{id}/cancel
    [HttpPost("{id:guid}/cancel")]
    [Authorize(Roles = RoleNames.Shipper)] // yalnız Yük Veren; ilanın sahibi mi kontrolü handler'da (değilse 404)
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Cancel(Guid id, CancellationToken cancellationToken)
    {
        await cancelListing.HandleAsync(new CancelListingCommand(id, CurrentUserId), cancellationToken);
        return NoContent();
    }

    // Sayfa başına en çok kayıt: tek istekte aşırı veri çekilmesin.
    private const int MaxPageSize = 50;

    // Jetondaki 'sub' (kullanıcı numarası). MapInboundClaims kapalı olduğu için adı 'sub'dır.
    private Guid CurrentUserId => Guid.Parse(User.FindFirst("sub")!.Value);
}
