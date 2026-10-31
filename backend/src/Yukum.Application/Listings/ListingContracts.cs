using Yukum.Domain.Accounts;

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
    decimal? MyOfferAmount = null); // yalnız Taşımacı'nın açık ilan listesinde dolar: bu ilana verdiği teklif, yoksa null

/// <summary>Sorgu: Yük Veren'in kendi ilanları.</summary>
public sealed record GetMyListingsQuery(Guid ShipperId);

/// <summary>Sorgu: tüm açık ilanlar (Taşımacı'nın göreceği liste).</summary>
public sealed record GetOpenListingsQuery(Guid CarrierId);
