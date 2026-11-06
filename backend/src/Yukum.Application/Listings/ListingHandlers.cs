using FluentValidation;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Domain.Listings;

namespace Yukum.Application.Listings;

/// <summary>İlanı doğrular, kaydeder ve oluşan ilanı döndürür.</summary>
public sealed class CreateListingHandler(
    IValidator<CreateListingCommand> validator,
    IRepository<Listing> listings,
    IGeographyRepository geography,
    IUnitOfWork unitOfWork) : ICommandHandler<CreateListingCommand, ListingDto>
{
    /// <summary>Doğrulama hatasında ValidationException fırlatır (API'de 400).</summary>
    public async Task<ListingDto> HandleAsync(CreateListingCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);

        var listing = new Listing
        {
            ShipperId = command.ShipperId,
            Title = command.Title!.Trim(),
            Description = string.IsNullOrWhiteSpace(command.Description) ? null : command.Description.Trim(),
            WeightKg = command.WeightKg,
            VehicleType = command.VehicleType,
            FromCityId = command.FromCityId,
            FromDistrictId = command.FromDistrictId,
            ToCityId = command.ToCityId,
            ToDistrictId = command.ToDistrictId,
            PickupDate = command.PickupDate,
            Budget = command.Budget,
            Status = ListingStatus.Open
        };

        listings.Add(listing);
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return ToDto(listing, await CityNamesAsync(geography, cancellationToken), await DistrictNamesAsync(geography, [listing], cancellationToken));
    }

    /// <summary>İl numarası → il adı sözlüğü (il listesi önbellekli olduğu için ucuzdur).</summary>
    internal static async Task<Dictionary<int, string>> CityNamesAsync(IGeographyRepository geography, CancellationToken ct) =>
        (await geography.ListCitiesAsync(ct)).ToDictionary(c => c.Id, c => c.Name);

    /// <summary>İlanlardaki illerin ilçelerini okuyup ilçe numarası → ilçe adı sözlüğü yapar (ilçe listeleri il başına önbellekli).</summary>
    internal static async Task<Dictionary<int, string>> DistrictNamesAsync(IGeographyRepository geography, IEnumerable<Listing> items, CancellationToken ct)
    {
        var result = new Dictionary<int, string>();
        // Yalnız ilanlarda geçen illerin ilçeleri okunur (en fazla birkaç il).
        var cityIds = items.SelectMany(l => new[] { l.FromCityId, l.ToCityId }).Distinct();
        foreach (var cityId in cityIds)
            foreach (var d in await geography.ListDistrictsAsync(cityId, ct))
                result[d.Id] = d.Name;
        return result;
    }

    /// <summary>İlanı istemciye giden modele çevirir; il ve ilçe adlarını sözlüklerden alır.</summary>
    internal static ListingDto ToDto(Listing l, IReadOnlyDictionary<int, string> cityNames, IReadOnlyDictionary<int, string> districtNames) => new(l.Id, l.Title, l.Description,
        l.WeightKg, l.VehicleType, l.FromCityId, cityNames[l.FromCityId], l.FromDistrictId, districtNames[l.FromDistrictId],
        l.ToCityId, cityNames[l.ToCityId], l.ToDistrictId, districtNames[l.ToDistrictId], l.PickupDate, l.Budget, l.CreatedAt);
}

/// <summary>Yük Veren'in kendi ilanlarını yeniden eskiye sıralı getirir.</summary>
public sealed class GetMyListingsHandler(IRepository<Listing> listings, IGeographyRepository geography)
    : IQueryHandler<GetMyListingsQuery, IReadOnlyList<ListingDto>>
{
    /// <summary>Yalnız jetondaki kullanıcının AÇIK ilanları döner.</summary>
    public async Task<IReadOnlyList<ListingDto>> HandleAsync(GetMyListingsQuery query, CancellationToken cancellationToken = default)
    {
        // Ana sayfada yalnız AÇIK (canlı) ilanlar: teklifi kabul edilen ilan atanmıştır, geçmişe (offers/history) gider.
        var mine = await listings.ListAsync(l => l.ShipperId == query.ShipperId && l.Status == ListingStatus.Open, asNoTracking: true, cancellationToken);
        var names = await CreateListingHandler.CityNamesAsync(geography, cancellationToken);
        var districts = await CreateListingHandler.DistrictNamesAsync(geography, mine, cancellationToken);
        return mine.OrderByDescending(l => l.CreatedAt).Select(l => CreateListingHandler.ToDto(l, names, districts)).ToList();
    }
}

/// <summary>Taşımacı için açık ilanları filtreleyip sıralayıp sayfalayarak getirir.</summary>
public sealed class GetOpenListingsHandler(IListingSearchRepository search, IRepository<Listing> listings, IGeographyRepository geography)
    : IQueryHandler<GetOpenListingsQuery, PagedResult<ListingDto>>
{
    /// <summary>
    /// Yalnız Open ilanlar, bu taşımacının teklif vermediği olanlar. Filtre/sıralama/sayfalama veritabanında yapılır;
    /// yalnız "en yakın" sıralamasında mesafe bellekte hesaplanır (önce hafif özet, sonra yalnız sayfanın ilanları okunur).
    /// </summary>
    public async Task<PagedResult<ListingDto>> HandleAsync(GetOpenListingsQuery query, CancellationToken cancellationToken = default)
    {
        var hasLocation = query.Lat is not null && query.Lon is not null;
        // Sıralama verilmediyse: konum varsa en yakın, yoksa en yeni. Konumsuz "en yakın" istenirse en yeniye düşer (uç zaten 400 verir).
        var sort = query.Sort ?? (hasLocation ? ListingSort.Nearest : ListingSort.Newest);
        if (sort == ListingSort.Nearest && !hasLocation) sort = ListingSort.Newest;

        var filter = new OpenListingFilter(query.CarrierId, query.FromCityId, query.FromDistrictId, query.ToCityId,
            query.MinBudget, query.MaxBudget, query.VehicleType, query.PickupFrom, query.PickupTo);

        IReadOnlyList<Listing> items;
        int total;
        Dictionary<int, (double Lat, double Lon)> points = [];

        if (sort == ListingSort.Nearest)
        {
            // 1) Filtreye uyan hepsinin hafif özeti (ilan numarası + kalkış yeri) 2) mesafeyle sırala 3) yalnız bu sayfanın ilanlarını oku.
            var all = await search.ListOpenPointsAsync(filter, cancellationToken);
            points = await DistrictPointsAsync(geography, all.Select(p => p.FromCityId).Distinct(), cancellationToken);
            double Km(ListingPoint p) => points.TryGetValue(p.FromDistrictId, out var pt)
                ? GeoMath.DistanceKm(query.Lat!.Value, query.Lon!.Value, pt.Lat, pt.Lon) : double.MaxValue;

            var pageIds = all.OrderBy(Km).ThenByDescending(p => p.CreatedAt).ThenBy(p => p.Id) // son anahtar Id: kararlı sıra
                .Skip((query.Page - 1) * query.PageSize).Take(query.PageSize).Select(p => p.Id).ToList();
            var loaded = await listings.ListAsync(l => pageIds.Contains(l.Id), asNoTracking: true, cancellationToken);
            var byId = loaded.ToDictionary(l => l.Id);
            items = pageIds.Where(byId.ContainsKey).Select(id => byId[id]).ToList(); // sıra pageIds'teki gibi
            total = all.Count;
        }
        else
        {
            var page = await search.SearchOpenAsync(filter, sort, query.Page, query.PageSize, cancellationToken);
            items = page.Items;
            total = page.TotalCount;
            if (hasLocation) points = await DistrictPointsAsync(geography, items.Select(l => l.FromCityId).Distinct(), cancellationToken);
        }

        var names = await CreateListingHandler.CityNamesAsync(geography, cancellationToken);
        var districts = await CreateListingHandler.DistrictNamesAsync(geography, items, cancellationToken);
        // Listedeki ilanlar bu taşımacının DOKUNMADIĞI ilanlardır (teklif verdikleri Tekliflerim'e geçer), bu yüzden MyOffer* alanları burada boş kalır.
        var dtos = items.Select(l => CreateListingHandler.ToDto(l, names, districts) with
        {
            DistanceKm = hasLocation && points.TryGetValue(l.FromDistrictId, out var p)
                ? Math.Round(GeoMath.DistanceKm(query.Lat!.Value, query.Lon!.Value, p.Lat, p.Lon), 1)
                : null
        }).ToList();
        return new PagedResult<ListingDto>(dtos, query.Page, query.PageSize, total);
    }

    // İlçe numarası → (enlem, boylam); yalnız verilen illerin ilçeleri okunur (ilçe listeleri il başına önbellekli).
    private static async Task<Dictionary<int, (double Lat, double Lon)>> DistrictPointsAsync(
        IGeographyRepository geography, IEnumerable<int> cityIds, CancellationToken ct)
    {
        var result = new Dictionary<int, (double, double)>();
        foreach (var cityId in cityIds)
            foreach (var d in await geography.ListDistrictsAsync(cityId, ct))
                result[d.Id] = (d.Latitude, d.Longitude);
        return result;
    }
}
