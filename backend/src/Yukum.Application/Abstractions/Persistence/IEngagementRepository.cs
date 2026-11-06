namespace Yukum.Application.Abstractions.Persistence;

/// <summary>İlanın görüntülenme / favori / teklif sayıları.</summary>
public sealed record ListingStats(int ViewCount, int FavoriteCount, int OfferCount);

/// <summary>Favori ve görüntülenme kayıtları. Çift kayıt yarışlarını (iki istek aynı anda) veritabanı benzersiz indeksiyle çözen kısım Infrastructure'dadır.</summary>
public interface IEngagementRepository
{
    /// <summary>Favoriye ekler. Zaten favoriyse hiçbir şey yapmaz (idempotent: iki kez çağırmak hata vermez, sayı şişmez).</summary>
    Task AddFavoriteAsync(Guid userId, Guid listingId, CancellationToken cancellationToken = default);

    /// <summary>Favoriden çıkarır. Favori değilse hiçbir şey yapmaz (idempotent).</summary>
    Task RemoveFavoriteAsync(Guid userId, Guid listingId, CancellationToken cancellationToken = default);

    /// <summary>Verilen ilanlardan hangileri bu kullanıcının favorisi.</summary>
    Task<HashSet<Guid>> GetFavoriteIdsAsync(Guid userId, IEnumerable<Guid> listingIds, CancellationToken cancellationToken = default);

    /// <summary>Kullanıcının favori ilan numaraları, en son eklenen üstte.</summary>
    Task<IReadOnlyList<Guid>> ListFavoriteListingIdsAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>Görüntülenmeyi yazar. Aynı kişi aynı gün için zaten yazılmışsa hiçbir şey yapmaz.</summary>
    Task RecordViewAsync(Guid listingId, Guid viewerId, DateOnly day, CancellationToken cancellationToken = default);

    /// <summary>İlanın görüntülenme (benzersiz kişi-gün), favori ve teklif sayıları (geri çekilen teklifler sayılmaz).</summary>
    Task<ListingStats> GetStatsAsync(Guid listingId, CancellationToken cancellationToken = default);
}
