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

    /// <summary>İlanlardaki kalkış illerinin ilçe koordinatları: ilçe numarası → (enlem, boylam). Mesafe hesabı için (ilçe listeleri il başına önbellekli).</summary>
    internal static async Task<Dictionary<int, (double Lat, double Lon)>> DistrictPointsAsync(IGeographyRepository geography, IEnumerable<Listing> items, CancellationToken ct)
    {
        var result = new Dictionary<int, (double, double)>();
        foreach (var cityId in items.Select(l => l.FromCityId).Distinct())
            foreach (var d in await geography.ListDistrictsAsync(cityId, ct))
                result[d.Id] = (d.Latitude, d.Longitude);
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

/// <summary>Taşımacı için açık ilanları yeniden eskiye sıralı getirir.</summary>
public sealed class GetOpenListingsHandler(IRepository<Listing> listings, IRepository<Offer> offers, IGeographyRepository geography)
    : IQueryHandler<GetOpenListingsQuery, IReadOnlyList<ListingDto>>
{
    /// <summary>Yalnız durumu Open olan ilanlar döner; kalkış ili/ilçesi verilmişse yalnız onlar (filtre).</summary>
    public async Task<IReadOnlyList<ListingDto>> HandleAsync(GetOpenListingsQuery query, CancellationToken cancellationToken = default)
    {
        // Filtre SQL'de yapılır (WHERE): "filtre boşsa (null) o koşul geçerli sayılır, doluysa eşleşme aranır".
        // Değişkenleri dışarıda alıyoruz ki EF Core bunları SQL parametresine çevirebilsin.
        var cityId = query.FromCityId;
        var districtId = query.FromDistrictId;
        var open = await listings.ListAsync(
            l => l.Status == ListingStatus.Open
                 && (cityId == null || l.FromCityId == cityId)
                 && (districtId == null || l.FromDistrictId == districtId),
            asNoTracking: true, cancellationToken);
        var names = await CreateListingHandler.CityNamesAsync(geography, cancellationToken);
        var districts = await CreateListingHandler.DistrictNamesAsync(geography, open, cancellationToken);
        // Bu taşımacının verdiği teklifler: ilan numarası → tutar (listede "Teklif verildi" göstermek için).
        // Geçmişinden sildiği teklifler listede de görünmez (HiddenByCarrier).
        var allMine = await offers.ListAsync(o => o.CarrierId == query.CarrierId, asNoTracking: true, cancellationToken);
        var myOffers = allMine.Where(o => !o.HiddenByCarrier).ToDictionary(o => o.ListingId);
        // Ana liste = yalnız DOKUNULMAMIŞ ilanlar: taşımacının teklif verdiği ilan, durumu ne olursa olsun (bekleyen/kabul/red)
        // ana listeden kalkar ve "Tekliflerim"e geçer. Geçmişinden silmiş olsa bile ana listeye geri dönmez.
        var touchedListingIds = allMine.Select(o => o.ListingId).ToHashSet();
        open = open.Where(l => !touchedListingIds.Contains(l.Id)).ToList();
        // Konum verilmişse her ilanın kalkış ilçesine mesafe hesaplanır (kuş uçuşu, Haversine); verilmemişse null.
        var hasLocation = query.Lat is not null && query.Lon is not null;
        var points = hasLocation ? await CreateListingHandler.DistrictPointsAsync(geography, open, cancellationToken) : [];

        var dtos = open.Select(l => CreateListingHandler.ToDto(l, names, districts) with
        {
            MyOfferAmount = myOffers.TryGetValue(l.Id, out var mine) ? mine.Amount : null,
            MyOfferStatus = myOffers.TryGetValue(l.Id, out var mine2) ? mine2.Status : null,
            DistanceKm = hasLocation && points.TryGetValue(l.FromDistrictId, out var p)
                ? Math.Round(GeoMath.DistanceKm(query.Lat!.Value, query.Lon!.Value, p.Lat, p.Lon), 1)
                : null
        });

        // Sıralama: konum varsa en yakın üstte (eşitlikte en yeni), yoksa en yeni üstte.
        return (hasLocation
                ? dtos.OrderBy(d => d.DistanceKm ?? double.MaxValue).ThenByDescending(d => d.CreatedAt)
                : dtos.OrderByDescending(d => d.CreatedAt))
            .ToList();
    }
}
