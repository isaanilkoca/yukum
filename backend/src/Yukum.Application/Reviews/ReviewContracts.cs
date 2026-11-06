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
public sealed record CarrierProfileDto(Guid Id, string FullName, string? About, decimal AverageRating, int RatingCount, int CompletedJobCount, IReadOnlyList<ReviewItemDto> Reviews);
