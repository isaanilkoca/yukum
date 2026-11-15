namespace Yukum.Application.Reviews;

/// <summary>İstemcinin gönderdiği puan (iş numarası adresten, Yük Veren jetondan gelir).</summary>
public sealed record CreateReviewRequest(int Rating, string? Comment);

/// <summary>Komut: Yük Veren tamamlanmış işi puanlar.</summary>
public sealed record CreateReviewCommand(Guid OfferId, Guid ShipperId, int Rating, string? Comment);

/// <summary>Kaydedilen puan.</summary>
public sealed record ReviewDto(Guid Id, Guid OfferId, int Rating, string? Comment);

/// <summary>Sorgu: bir Taşımacı'nın herkese açık profili.</summary>
public sealed record GetCarrierProfileQuery(Guid CarrierId);

/// <summary>Profildeki bir yorum satırı (Yük Veren adı kısaltılır: "Ali V.").</summary>
public sealed record ReviewItemDto(int Rating, string? Comment, string ShipperName, string ListingTitle, string FromCityName, string ToCityName, DateTime CreatedAt);

/// <summary>Taşımacı profili: ad, ortalama puan, puan sayısı, tamamlanan iş, son yorumlar (yeniden eskiye, en çok 20).</summary>
public sealed record CarrierProfileDto(Guid Id, string FullName, string? About, decimal AverageRating, int RatingCount, int CompletedJobCount, IReadOnlyList<ReviewItemDto> Reviews,
    string? AvatarUrl, string? CityName, DateTime MemberSince,
    IReadOnlyList<PublicVehicleDto> Vehicles); // 15 Kasım (8. adım): sona eklendi → eski iOS sürümleri bozulmaz (fazla alanı yok sayar)
// NEDEN varsayılansız (= default yok): DTO'daki "DateTime/Guid X = default" OpenAPI belgesini (/openapi/v1.json) 500'e düşürüyordu; ApiConventionTests yakaladı.

// ─── Yük Veren'in herkese açık profili (15 Kasım, 8. adım: "kullanıcılar birbirinin profilini göremiyor mu?") ───
// GİZLİLİK: telefon, e-posta, vergi no/dairesi YOK. İletişim yalnız sohbetten (iş kabul edilince). Gösterilen: kim olduğu + güvenilirlik işaretleri.

/// <summary>Profilde görünen araç (15 Kasım): tür, marka, model, yıl, kapasite. PLAKA YOK (kişisel/ticari bilgi; profil herkese açık).</summary>
public sealed record PublicVehicleDto(Yukum.Domain.Accounts.VehicleType Type, string? Brand, string? Model, int? Year, int? CapacityKg);

/// <summary>Sorgu: bir Yük Veren'in herkese açık profili.</summary>
public sealed record GetShipperProfileQuery(Guid ShipperId);

/// <summary>Yük Veren profili: ad, fotoğraf, firma, il, hakkında, üyelik tarihi, tamamlanan/açık ilan sayısı.</summary>
public sealed record ShipperProfileDto(Guid Id, string FullName, string? AvatarUrl, string? CompanyName, string? CityName, string? About,
    DateTime MemberSince, int CompletedListingCount, int OpenListingCount);
