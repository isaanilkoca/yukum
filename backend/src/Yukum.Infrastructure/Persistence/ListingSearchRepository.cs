using Microsoft.EntityFrameworkCore;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Application.Listings;
using Yukum.Domain.Accounts;
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
            ListingSort.PickupSoonest => query.OrderBy(l => l.PickupDate).ThenByDescending(l => l.CreatedAt).ThenBy(l => l.Id), // 15 Kasım
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

        // Ana liste = yalnız DOKUNULMAMIŞ ilanlar: bu taşımacının teklif verdiği ilan listeden çıkar.
        // İSTİSNA (15 Kasım, kullanıcı: "karşılıklı iptalden sonra ilan aynı taşımacıya tekrar düşmüyor"): KARŞILIKLI İPTAL edilmiş teklif sayılmaz →
        //   Yük Veren ilanı yeniden yayınlarsa (CancelRequestHandlers: reopen) aynı Taşımacı da görür ve YENİ teklif verebilir (CreateOfferHandler).
        // SQL: WHERE NOT EXISTS (SELECT 1 FROM Offers o WHERE o.ListingId = l.Id AND o.CarrierId = @carrierId AND o.MutuallyCancelled = 0)
        query = query.Where(l => !context.Offers.Any(o => o.ListingId == l.Id && o.CarrierId == carrierId && !o.MutuallyCancelled));

        // ENGEL (15 Kasım): Taşımacı ile ilan sahibi arasında engel varsa (iki yönden biri) ilan görünmez.
        // SQL: AND NOT EXISTS (SELECT 1 FROM UserBlocks b WHERE (b.BlockerId=@carrierId AND b.BlockedId=l.ShipperId) OR (b.BlockerId=l.ShipperId AND b.BlockedId=@carrierId))
        query = query.Where(l => !context.UserBlocks.Any(b =>
            (b.BlockerId == carrierId && b.BlockedId == l.ShipperId) || (b.BlockerId == l.ShipperId && b.BlockedId == carrierId)));

        if (f.FromCityId is { } fromCity) query = query.Where(l => l.FromCityId == fromCity);
        if (f.FromDistrictId is { } fromDistrict) query = query.Where(l => l.FromDistrictId == fromDistrict);
        if (f.ToCityId is { } toCity) query = query.Where(l => l.ToCityId == toCity);
        // Bütçesi boş (null) ilan, fiyat aralığı verilince eşleşmez (karşılaştırma null ile false olur): fiyatı bilinmeyen aralığa girmez.
        if (f.MinBudget is { } min) query = query.Where(l => l.Budget >= min);
        if (f.MaxBudget is { } max) query = query.Where(l => l.Budget <= max);
        // Araç filtresi (15 Kasım): "Farketmez" (Any) ilanlar HER araç filtresinde görünür; filtre olarak Any seçilirse süzme yapılmaz.
        if (f.VehicleType is { } vehicle && vehicle != VehicleType.Any) query = query.Where(l => l.VehicleType == vehicle || l.VehicleType == VehicleType.Any);
        // "Yalnız araçlarıma uygun" (15 Kasım): uygun türler handler'da hesaplanır (Application/Vehicles/VehicleCompatibility: büyük araç küçüğü kapsar)
        // SQL: AND l.VehicleType IN (1, 2, 3, 5, 100)
        if (f.AllowedVehicleTypes is { } allowed) query = query.Where(l => allowed.Contains(l.VehicleType));
        // Ağırlık aralığı (15 Kasım)
        if (f.MinWeightKg is { } minKg) query = query.Where(l => l.WeightKg >= minKg);
        if (f.MaxWeightKg is { } maxKg) query = query.Where(l => l.WeightKg <= maxKg);
        // Uzaklık filtresinden kalanlar (15 Kasım): handler mesafeyi ilçe koordinatıyla bellekte hesaplar, buraya numara listesi gelir | SQL: AND l.Id IN (...)
        if (f.OnlyIds is { } only) query = query.Where(l => only.Contains(l.Id));
        if (f.PickupFrom is { } from) query = query.Where(l => l.PickupDate >= from);
        if (f.PickupTo is { } to) query = query.Where(l => l.PickupDate <= to);
        return query;
    }
}
