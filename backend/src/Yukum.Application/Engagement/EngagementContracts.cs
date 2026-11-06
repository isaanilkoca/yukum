namespace Yukum.Application.Engagement;

/// <summary>Komut: Taşımacı bir ilanı favoriler (IsFavorite=true) ya da favoriden çıkarır (false). İkisi de tekrar çağrılabilir (idempotent).</summary>
public sealed record SetFavoriteCommand(Guid UserId, Guid ListingId, bool IsFavorite);

/// <summary>Komut: Taşımacı ilan detayını açtı; görüntülenme kaydı (kişi başına günde bir).</summary>
public sealed record RecordViewCommand(Guid ViewerId, Guid ListingId);

/// <summary>Sorgu: Taşımacı'nın favori ve hâlâ açık ilanları.</summary>
public sealed record GetFavoriteListingsQuery(Guid CarrierId);

/// <summary>Sorgu: ilan sahibi kendi ilanının sayılarını ister.</summary>
public sealed record GetListingStatsQuery(Guid ListingId, Guid ShipperId);

/// <summary>İlan sahibine giden sayılar.</summary>
public sealed record ListingStatsDto(int ViewCount, int FavoriteCount, int OfferCount);
