using Yukum.Domain.Accounts;
using Yukum.Domain.Listings;

namespace Yukum.Application.Offers;

/// <summary>İstemcinin gönderdiği teklif (ilan numarası adresten, taşımacı jetondan gelir).</summary>
// 15 Kasım: VehicleId (Araçlarım'dan; tek aracı varsa boş bırakılabilir) + EstimatedDeliveryDate (zorunlu)
public sealed record CreateOfferRequest(decimal Amount, string? Note, Guid? VehicleId, DateOnly? EstimatedDeliveryDate);

/// <summary>Komut: Taşımacı bir ilana teklif verir (varsa tutarını günceller).</summary>
public sealed record CreateOfferCommand(Guid ListingId, Guid CarrierId, decimal Amount, string? Note, Guid? VehicleId, DateOnly? EstimatedDeliveryDate);

/// <summary>İstemciye giden teklif bilgisi.</summary>
public sealed record OfferDto(Guid Id, Guid ListingId, decimal Amount, string? Note, OfferStatus Status);

/// <summary>Komut: Taşımacı bekleyen teklifini geri çeker.</summary>
public sealed record WithdrawOfferCommand(Guid OfferId, Guid CarrierId);

/// <summary>Komut: Taşımacı kabul edilmiş işin aşamasını bir sonrakine ilerletir.</summary>
public sealed record AdvanceStageCommand(Guid OfferId, Guid CarrierId);

/// <summary>Aşama ilerletme cevabı: teklif ve yeni aşaması.</summary>
public sealed record OfferStageDto(Guid Id, JobStage Stage);

/// <summary>Sorgu: Yük Veren kendi ilanına gelen teklifleri ister.</summary>
public sealed record GetListingOffersQuery(Guid ListingId, Guid ShipperId);

/// <summary>Yük Veren'in gördüğü teklif satırı (taşımacı adıyla).</summary>
public sealed record ListingOfferDto(Guid Id, string CarrierName, decimal Amount, string? Note, OfferStatus Status, DateTime CreatedAt,
    Guid CarrierId, decimal CarrierRating, int CarrierRatingCount,
    // 15 Kasım: Yük Veren sıralar/karşılaştırır (araç türü, marka-model, yaş, tamamlanan iş, teslim tarihi). Eski tekliflerde araç/tarih null.
    VehicleType? VehicleType, string? VehicleBrand, string? VehicleModel, int? VehicleYear, DateOnly? EstimatedDeliveryDate, int CarrierCompletedJobCount);

/// <summary>Komut: Yük Veren bir teklifi kabul eder (Accept=true) ya da reddeder (false).</summary>
public sealed record DecideOfferCommand(Guid OfferId, Guid ShipperId, bool Accept);

/// <summary>Sorgu: Taşımacı'nın verdiği tüm tekliflerin geçmişi (silinenler hariç).</summary>
public sealed record GetMyOffersQuery(Guid CarrierId);

/// <summary>Taşımacı geçmişindeki satır: teklif + ilanın özeti. IsNew: karar verildi ama taşımacı henüz görmedi.</summary>
public sealed record CarrierOfferDto(Guid Id, Guid ListingId, string ListingTitle,
    string FromCityName, string FromDistrictName, string ToCityName, string ToDistrictName,
    string ShipperName, Guid ShipperId, int WeightKg, DateOnly PickupDate, // ShipperId (15 Kasım): sohbetteki "Engelle / Şikâyet et" kimi hedefleyeceğini bilsin | varsayılansız (OpenAPI dersi)
    decimal Amount, string? Note, OfferStatus Status, bool IsNew, DateTime CreatedAt, DateTime? DecidedAt, JobStage Stage,
    CancelRequestDto? CancelRequest = null, bool MutuallyCancelled = false,
    bool HasMessages = false); // 15 Kasım: bekleyen teklifte sohbet başladı mı → iOS "Görüşülüyor" etiketi

/// <summary>Sorgu: Yük Veren'in karar verdiği (kabul/red) tekliflerin geçmişi (silinenler hariç).</summary>
public sealed record GetShipperOfferHistoryQuery(Guid ShipperId);

/// <summary>Yük Veren geçmişindeki satır: teklif + hangi ilan + hangi taşımacı.</summary>
public sealed record ShipperOfferHistoryDto(Guid Id, Guid ListingId, string ListingTitle,
    string FromCityName, string FromDistrictName, string ToCityName, string ToDistrictName, int WeightKg, DateOnly PickupDate,
    string CarrierName, decimal Amount, string? Note, OfferStatus Status, DateTime? DecidedAt, JobStage Stage, Guid CarrierId, bool Reviewed,
    CancelRequestDto? CancelRequest = null, bool MutuallyCancelled = false);

/// <summary>Komut: kullanıcı karara bağlanmış bir teklifi kendi geçmişinden siler (karşı tarafta durur).</summary>
public sealed record HideOfferCommand(Guid OfferId, Guid UserId, bool IsCarrier);

/// <summary>Sorgu: Taşımacı'nın görmediği karar sayısı ("bildirim rozeti").</summary>
public sealed record GetUnseenCountQuery(Guid CarrierId);

/// <summary>Karar bildirimi sayısı.</summary>
public sealed record UnseenCountDto(int Count);

/// <summary>Komut: Taşımacı karar bildirimlerini görüldü işaretler.</summary>
public sealed record MarkSeenCommand(Guid CarrierId);

/// <summary>Komut: kabul edilmiş işi bitir ("İşi bitir ve sil"). İki taraftan biri yapabilir; teklif ve ilan Tamamlandı olur, bitirenin geçmişinden ve mesajlarından silinir.</summary>
public sealed record CompleteOfferCommand(Guid OfferId, Guid UserId);

// ─── Karşılıklı iptal (15 Kasım) ───
/// <summary>İptal talebi gövdesi. ReopenListing yalnız Yük Veren için anlamlı (talebi o açıyorsa: onaylanınca ilan yeniden yayınlansın mı).</summary>
public sealed record CancelRequestBody(string? Reason, string? Note, bool? ReopenListing);

/// <summary>Onay gövdesi. ReopenListing: onaylayan Yük Veren ise ilanın ne olacağı (true: yeniden yayınla, false: kaldır).</summary>
public sealed record CancelApproveBody(bool? ReopenListing);

public sealed record RequestCancelCommand(Guid OfferId, Guid UserId, string? Reason, string? Note, bool? ReopenListing);

public sealed record RespondCancelCommand(Guid OfferId, Guid UserId, bool Approve, bool? ReopenListing);

public sealed record WithdrawCancelCommand(Guid OfferId, Guid UserId);

/// <summary>Listelerde iptal talebinin durumu (iki taraf için aynı biçim).</summary>
public sealed record CancelRequestDto(bool ByMe, string Reason, string? Note, DateTime RequestedAt);
