using Microsoft.EntityFrameworkCore;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Domain.Listings;

namespace Yukum.Infrastructure.Persistence;

/// <summary><see cref="IEngagementRepository"/>'nin EF Core uygulaması. Sayılar benzersiz satırlardan sayılır (COUNT): ayrı sayaç sütunu yok, dolayısıyla sayı hiçbir zaman satırlarla çelişemez.</summary>
public class EngagementRepository(AppDbContext context) : IEngagementRepository
{
    /// <inheritdoc />
    public async Task AddFavoriteAsync(Guid userId, Guid listingId, CancellationToken cancellationToken = default)
    {
        if (await context.Set<FavoriteListing>().AnyAsync(f => f.UserId == userId && f.ListingId == listingId, cancellationToken)) return; // zaten favori
        var favorite = new FavoriteListing { UserId = userId, ListingId = listingId };
        context.Add(favorite);
        await SaveIgnoringDuplicateAsync(favorite, cancellationToken);
    }

    /// <inheritdoc />
    public Task RemoveFavoriteAsync(Guid userId, Guid listingId, CancellationToken cancellationToken = default) =>
        // ExecuteDelete: SELECT yapmadan tek DELETE | satır yoksa 0 satır etkilenir, hata vermez (idempotent). Favori iz bırakması gerekmeyen bir tercih: kalıcı silinir.
        context.Set<FavoriteListing>().Where(f => f.UserId == userId && f.ListingId == listingId).ExecuteDeleteAsync(cancellationToken);

    /// <inheritdoc />
    public async Task<HashSet<Guid>> GetFavoriteIdsAsync(Guid userId, IEnumerable<Guid> listingIds, CancellationToken cancellationToken = default)
    {
        var ids = listingIds.ToList();
        var found = await context.Set<FavoriteListing>().AsNoTracking()
            .Where(f => f.UserId == userId && ids.Contains(f.ListingId)).Select(f => f.ListingId).ToListAsync(cancellationToken);
        return found.ToHashSet();
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<Guid>> ListFavoriteListingIdsAsync(Guid userId, CancellationToken cancellationToken = default) =>
        await context.Set<FavoriteListing>().AsNoTracking().Where(f => f.UserId == userId)
            .OrderByDescending(f => f.CreatedAt).Select(f => f.ListingId).ToListAsync(cancellationToken);

    /// <inheritdoc />
    public async Task RecordViewAsync(Guid listingId, Guid viewerId, DateOnly day, CancellationToken cancellationToken = default)
    {
        if (await context.Set<ListingView>().AnyAsync(v => v.ListingId == listingId && v.ViewerId == viewerId && v.Day == day, cancellationToken)) return;
        var view = new ListingView { ListingId = listingId, ViewerId = viewerId, Day = day };
        context.Add(view);
        await SaveIgnoringDuplicateAsync(view, cancellationToken);
    }

    /// <inheritdoc />
    public async Task<ListingStats> GetStatsAsync(Guid listingId, CancellationToken cancellationToken = default)
    {
        // Üç ayrı COUNT: her biri kendi indeksinden okunur (ListingId). Geri çekilen teklif "teklif gelmiş" sayılmaz.
        var views = await context.Set<ListingView>().CountAsync(v => v.ListingId == listingId, cancellationToken);
        var favorites = await context.Set<FavoriteListing>().CountAsync(f => f.ListingId == listingId, cancellationToken);
        var offers = await context.Offers.CountAsync(o => o.ListingId == listingId && o.Status != OfferStatus.Withdrawn, cancellationToken);
        return new ListingStats(views, favorites, offers);
    }

    // Kaydet; iki istek aynı anda aynı kaydı eklemeye çalışırsa ikincisi benzersiz indeksi ihlal eder (DbUpdateException): hata değil, "zaten var" demektir.
    private async Task SaveIgnoringDuplicateAsync(object entity, CancellationToken cancellationToken)
    {
        try { await context.SaveChangesAsync(cancellationToken); }
        catch (DbUpdateException)
        {
            context.Entry(entity).State = EntityState.Detached; // başarısız ekleme izlemeden çıkarılır, sonraki işlemleri bozmaz
        }
    }
}
