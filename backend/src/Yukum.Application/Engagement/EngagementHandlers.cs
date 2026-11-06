using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Application.Listings;
using Yukum.Domain.Listings;

namespace Yukum.Application.Engagement;

/// <summary>Favoriye ekler / çıkarır. İlan yoksa 404; zaten öyleyse sessizce başarılı (idempotent).</summary>
public sealed class SetFavoriteHandler(IRepository<Listing> listings, IEngagementRepository engagement) : ICommandHandler<SetFavoriteCommand, bool>
{
    // FONKSİYON ROLÜ: API'NİN İŞ MANTIĞI | EngagementController çağırır: ilan var mı bakar, favori satırını ekler/siler
    /// <summary>İlan yoksa NotFoundException (404).</summary>
    public async Task<bool> HandleAsync(SetFavoriteCommand command, CancellationToken cancellationToken = default)
    {
        if (!await listings.AnyAsync(l => l.Id == command.ListingId, cancellationToken)) throw new NotFoundException("İlan bulunamadı.");
        if (command.IsFavorite) await engagement.AddFavoriteAsync(command.UserId, command.ListingId, cancellationToken);
        else await engagement.RemoveFavoriteAsync(command.UserId, command.ListingId, cancellationToken);
        return true;
    }
}

/// <summary>İlan detayı açıldı: görüntülenmeyi yazar (aynı kişi aynı gün tek sayılır).</summary>
public sealed class RecordViewHandler(IRepository<Listing> listings, IEngagementRepository engagement, TimeProvider time) : ICommandHandler<RecordViewCommand, bool>
{
    /// <summary>İlan yoksa 404. İlan sahibinin kendi bakışı sayılmaz (sahibi zaten Taşımacı değil, ama savunma amaçlı denetlenir).</summary>
    public async Task<bool> HandleAsync(RecordViewCommand command, CancellationToken cancellationToken = default)
    {
        var listing = await listings.GetByIdAsync(command.ListingId, asNoTracking: true, cancellationToken)
            ?? throw new NotFoundException("İlan bulunamadı.");
        if (listing.ShipperId == command.ViewerId) return true; // kendi ilanına bakış sayılmaz
        var today = DateOnly.FromDateTime(time.GetUtcNow().UtcDateTime);
        await engagement.RecordViewAsync(listing.Id, command.ViewerId, today, cancellationToken);
        return true;
    }
}

/// <summary>Taşımacı'nın favori ilanları (yalnız hâlâ açık olanlar), en son favorilenen üstte.</summary>
public sealed class GetFavoriteListingsHandler(IEngagementRepository engagement, IRepository<Listing> listings, IGeographyRepository geography)
    : IQueryHandler<GetFavoriteListingsQuery, IReadOnlyList<ListingDto>>
{
    /// <summary>Kaldırılmış ya da atanmış ilanlar listeden düşer.</summary>
    public async Task<IReadOnlyList<ListingDto>> HandleAsync(GetFavoriteListingsQuery query, CancellationToken cancellationToken = default)
    {
        var ids = await engagement.ListFavoriteListingIdsAsync(query.CarrierId, cancellationToken); // sıra: son favorilenen önce
        var loaded = (await listings.ListAsync(l => ids.Contains(l.Id) && l.Status == ListingStatus.Open, asNoTracking: true, cancellationToken))
            .ToDictionary(l => l.Id);
        var items = ids.Where(loaded.ContainsKey).Select(id => loaded[id]).ToList();

        var names = await CreateListingHandler.CityNamesAsync(geography, cancellationToken);
        var districts = await CreateListingHandler.DistrictNamesAsync(geography, items, cancellationToken);
        return items.Select(l => CreateListingHandler.ToDto(l, names, districts) with { IsFavorite = true }).ToList();
    }
}

/// <summary>İlan sahibi kendi ilanının görüntülenme / favori / teklif sayılarını görür.</summary>
public sealed class GetListingStatsHandler(IRepository<Listing> listings, IEngagementRepository engagement)
    : IQueryHandler<GetListingStatsQuery, ListingStatsDto>
{
    /// <summary>İlan yoksa ya da başkasınınsa 404 (varlığı sızdırılmaz).</summary>
    public async Task<ListingStatsDto> HandleAsync(GetListingStatsQuery query, CancellationToken cancellationToken = default)
    {
        var listing = await listings.GetByIdAsync(query.ListingId, asNoTracking: true, cancellationToken);
        if (listing is null || listing.ShipperId != query.ShipperId) throw new NotFoundException("İlan bulunamadı.");
        var stats = await engagement.GetStatsAsync(listing.Id, cancellationToken);
        return new ListingStatsDto(stats.ViewCount, stats.FavoriteCount, stats.OfferCount);
    }
}
