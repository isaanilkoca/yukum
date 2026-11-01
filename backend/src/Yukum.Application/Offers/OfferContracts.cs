using Yukum.Domain.Listings;

namespace Yukum.Application.Offers;

/// <summary>İstemcinin gönderdiği teklif (ilan numarası adresten, taşımacı jetondan gelir).</summary>
public sealed record CreateOfferRequest(decimal Amount, string? Note);

/// <summary>Komut: Taşımacı bir ilana teklif verir (varsa tutarını günceller).</summary>
public sealed record CreateOfferCommand(Guid ListingId, Guid CarrierId, decimal Amount, string? Note);

/// <summary>İstemciye giden teklif bilgisi.</summary>
public sealed record OfferDto(Guid Id, Guid ListingId, decimal Amount, string? Note, OfferStatus Status);

/// <summary>Sorgu: Yük Veren kendi ilanına gelen teklifleri ister.</summary>
public sealed record GetListingOffersQuery(Guid ListingId, Guid ShipperId);

/// <summary>Yük Veren'in gördüğü teklif satırı (taşımacı adıyla).</summary>
public sealed record ListingOfferDto(Guid Id, string CarrierName, decimal Amount, string? Note, OfferStatus Status, DateTime CreatedAt);

/// <summary>Komut: Yük Veren bir teklifi kabul eder (Accept=true) ya da reddeder (false).</summary>
public sealed record DecideOfferCommand(Guid OfferId, Guid ShipperId, bool Accept);

/// <summary>Sorgu: Taşımacı'nın verdiği tüm tekliflerin geçmişi (silinenler hariç).</summary>
public sealed record GetMyOffersQuery(Guid CarrierId);

/// <summary>Taşımacı geçmişindeki satır: teklif + ilanın özeti. IsNew: karar verildi ama taşımacı henüz görmedi.</summary>
public sealed record CarrierOfferDto(Guid Id, Guid ListingId, string ListingTitle,
    string FromCityName, string FromDistrictName, string ToCityName, string ToDistrictName,
    string ShipperName, int WeightKg, DateOnly PickupDate,
    decimal Amount, string? Note, OfferStatus Status, bool IsNew, DateTime CreatedAt, DateTime? DecidedAt);

/// <summary>Sorgu: Yük Veren'in karar verdiği (kabul/red) tekliflerin geçmişi (silinenler hariç).</summary>
public sealed record GetShipperOfferHistoryQuery(Guid ShipperId);

/// <summary>Yük Veren geçmişindeki satır: teklif + hangi ilan + hangi taşımacı.</summary>
public sealed record ShipperOfferHistoryDto(Guid Id, Guid ListingId, string ListingTitle,
    string FromCityName, string FromDistrictName, string ToCityName, string ToDistrictName, int WeightKg, DateOnly PickupDate,
    string CarrierName, decimal Amount, string? Note, OfferStatus Status, DateTime? DecidedAt);

/// <summary>Komut: kullanıcı karara bağlanmış bir teklifi kendi geçmişinden siler (karşı tarafta durur).</summary>
public sealed record HideOfferCommand(Guid OfferId, Guid UserId, bool IsCarrier);

/// <summary>Sorgu: Taşımacı'nın görmediği karar sayısı ("bildirim rozeti").</summary>
public sealed record GetUnseenCountQuery(Guid CarrierId);

/// <summary>Karar bildirimi sayısı.</summary>
public sealed record UnseenCountDto(int Count);

/// <summary>Komut: Taşımacı karar bildirimlerini görüldü işaretler.</summary>
public sealed record MarkSeenCommand(Guid CarrierId);
