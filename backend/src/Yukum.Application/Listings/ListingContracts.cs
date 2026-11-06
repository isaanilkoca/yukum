using Yukum.Domain.Accounts;
using Yukum.Domain.Listings;

namespace Yukum.Application.Listings;

/// <summary>Komut: yeni ilan aç. Alanlar iOS'taki ilan formuyla aynıdır; ilan sahibi jetondan gelir.</summary>
public sealed record CreateListingCommand(
    Guid ShipperId,
    string? Title,
    string? Description,
    int WeightKg,
    VehicleType VehicleType,
    int FromCityId,
    int FromDistrictId,
    int ToCityId,
    int ToDistrictId,
    DateOnly PickupDate,
    decimal? Budget);

/// <summary>İstemciden gelen ilan açma gövdesi (ShipperId yok: güvenlik için sunucu jetondan ekler).</summary>
public sealed record CreateListingRequest(
    string? Title,
    string? Description,
    int WeightKg,
    VehicleType VehicleType,
    int FromCityId,
    int FromDistrictId,
    int ToCityId,
    int ToDistrictId,
    DateOnly PickupDate,
    decimal? Budget);

/// <summary>İstemciye giden ilan bilgisi.</summary>
public sealed record ListingDto(
    Guid Id,
    string Title,
    string? Description,
    int WeightKg,
    VehicleType VehicleType,
    int FromCityId,
    string FromCityName,
    int FromDistrictId,
    string FromDistrictName,
    int ToCityId,
    string ToCityName,
    int ToDistrictId,
    string ToDistrictName,
    DateOnly PickupDate,
    decimal? Budget,
    DateTime CreatedAt,
    decimal? MyOfferAmount = null, // yalnız Taşımacı'nın açık ilan listesinde dolar: bu ilana verdiği teklif, yoksa null
    OfferStatus? MyOfferStatus = null, // aynı yerde o teklifin durumu (Pending/Rejected), yoksa null
    double? DistanceKm = null); // yalnız konum verilmişse dolar: Taşımacı'nın konumu ile ilanın kalkış noktası arası kuş uçuşu km

/// <summary>Sorgu: Yük Veren'in kendi ilanları.</summary>
public sealed record GetMyListingsQuery(Guid ShipperId);

/// <summary>Açık ilan listesinin sıralama seçenekleri.</summary>
public enum ListingSort
{
    /// <summary>En yeni ilan üstte (varsayılan).</summary>
    Newest,
    /// <summary>Bütçe artan (bütçesi belli olmayanlar en sonda).</summary>
    PriceAsc,
    /// <summary>Bütçe azalan (bütçesi belli olmayanlar en sonda).</summary>
    PriceDesc,
    /// <summary>Taşımacı'nın konumuna en yakın üstte (lat+lon gerekir).</summary>
    Nearest
}

/// <summary>
/// Sorgu: Taşımacı'nın göreceği açık ilanlar. Tüm filtreler isteğe bağlıdır (null = o koşul yok), sonuç sayfalıdır.
/// Sort verilmezse: konum varsa en yakın, yoksa en yeni.
/// </summary>
public sealed record GetOpenListingsQuery(
    Guid CarrierId,
    int? FromCityId = null,
    int? FromDistrictId = null,
    double? Lat = null,
    double? Lon = null,
    int? ToCityId = null,
    decimal? MinBudget = null,
    decimal? MaxBudget = null,
    VehicleType? VehicleType = null,
    DateOnly? PickupFrom = null,
    DateOnly? PickupTo = null,
    ListingSort? Sort = null,
    int Page = 1,
    int PageSize = 20);

/// <summary>Komut: ilan sahibi ilanı yayından kaldırır (açık ilan, ya da atanmış iş iptali).</summary>
public sealed record CancelListingCommand(Guid ListingId, Guid ShipperId);


/// <summary>Komut: ilan sahibi ilanın bilgilerini günceller (yalnız hâlâ açık ilan). Alanlar ilan açma ile aynıdır.</summary>
public sealed record UpdateListingCommand(
    Guid ListingId,
    Guid ShipperId,
    string? Title,
    string? Description,
    int WeightKg,
    VehicleType VehicleType,
    int FromCityId,
    int FromDistrictId,
    int ToCityId,
    int ToDistrictId,
    DateOnly PickupDate,
    decimal? Budget);

/// <summary>İstemciden gelen ilan güncelleme gövdesi (ilan numarası adresten, sahibi jetondan gelir). Tam değiştirme: tüm alanlar gönderilir.</summary>
public sealed record UpdateListingRequest(
    string? Title,
    string? Description,
    int WeightKg,
    VehicleType VehicleType,
    int FromCityId,
    int FromDistrictId,
    int ToCityId,
    int ToDistrictId,
    DateOnly PickupDate,
    decimal? Budget);
