using Microsoft.EntityFrameworkCore;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Application.Listings;
using Yukum.Domain.Listings;

namespace Yukum.Infrastructure.Persistence;

/// <summary><see cref="IListingSearchRepository"/>'nin EF Core uygulaması: dinamik filtre + kararlı sıralama + Skip/Take, hepsi tek SQL'de.</summary>
public class ListingSearchRepository(AppDbContext context) : IListingSearchRepository
{
    /// <inheritdoc />
    public async Task<PagedResult<Listing>> SearchOpenAsync(
        OpenListingFilter filter, ListingSort sort, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        if (sort == ListingSort.Nearest) throw new ArgumentException("Mesafe sıralaması bellekte yapılır (ListOpenPointsAsync).", nameof(sort));

        var query = Filtered(filter);
        var total = await query.CountAsync(cancellationToken); // SQL: SELECT COUNT(*) ... aynı WHERE

        // Kararlı sıralama: asıl anahtar eşit olsa bile son anahtar Id olduğu için sıra HER istekte aynıdır (sayfalar arası tekrar/kayıp olmaz).
        // "Budget == null" önce sıralanınca bütçesi belli olmayanlar (null) hep sonda kalır.
        var ordered = sort switch
        {
            ListingSort.PriceAsc => query.OrderBy(l => l.Budget == null).ThenBy(l => l.Budget).ThenByDescending(l => l.CreatedAt).ThenBy(l => l.Id),
            ListingSort.PriceDesc => query.OrderBy(l => l.Budget == null).ThenByDescending(l => l.Budget).ThenByDescending(l => l.CreatedAt).ThenBy(l => l.Id),
            _ => query.OrderByDescending(l => l.CreatedAt).ThenBy(l => l.Id)
        };

        // SQL: OFFSET (page-1)*pageSize ROWS FETCH NEXT pageSize ROWS ONLY
        var items = await ordered.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(cancellationToken);
        return new PagedResult<Listing>(items, page, pageSize, total);
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<ListingPoint>> ListOpenPointsAsync(OpenListingFilter filter, CancellationToken cancellationToken = default) =>
        await Filtered(filter).Select(l => new ListingPoint(l.Id, l.FromCityId, l.FromDistrictId, l.CreatedAt)).ToListAsync(cancellationToken);

    // Dinamik predicate: her filtre YALNIZ dolu ise sorguya Where olarak eklenir; EF hepsini tek SQL'e çevirir.
    // Değerleri yerel değişkene almak EF'in onları SQL parametresi yapmasını sağlar.
    private IQueryable<Listing> Filtered(OpenListingFilter f)
    {
        var carrierId = f.CarrierId;
        var query = context.Listings.AsNoTracking().Where(l => l.Status == ListingStatus.Open);

        // Ana liste = yalnız DOKUNULMAMIŞ ilanlar: bu taşımacının teklif verdiği ilan (durumu ne olursa olsun) listeden çıkar.
        // SQL: WHERE NOT EXISTS (SELECT 1 FROM Offers o WHERE o.ListingId = l.Id AND o.CarrierId = @carrierId)
        query = query.Where(l => !context.Offers.Any(o => o.ListingId == l.Id && o.CarrierId == carrierId));

        if (f.FromCityId is { } fromCity) query = query.Where(l => l.FromCityId == fromCity);
        if (f.FromDistrictId is { } fromDistrict) query = query.Where(l => l.FromDistrictId == fromDistrict);
        if (f.ToCityId is { } toCity) query = query.Where(l => l.ToCityId == toCity);
        // Bütçesi boş (null) ilan, fiyat aralığı verilince eşleşmez (karşılaştırma null ile false olur): fiyatı bilinmeyen aralığa girmez.
        if (f.MinBudget is { } min) query = query.Where(l => l.Budget >= min);
        if (f.MaxBudget is { } max) query = query.Where(l => l.Budget <= max);
        if (f.VehicleType is { } vehicle) query = query.Where(l => l.VehicleType == vehicle);
        if (f.PickupFrom is { } from) query = query.Where(l => l.PickupDate >= from);
        if (f.PickupTo is { } to) query = query.Where(l => l.PickupDate <= to);
        return query;
    }
}
