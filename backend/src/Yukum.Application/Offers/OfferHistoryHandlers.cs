using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Domain.Listings;

namespace Yukum.Application.Offers;

/// <summary>Taşımacı'nın tüm teklifleri (bekleyen, kabul, red), yeniden eskiye. Karar bildirimi "IsNew" ile işaretlenir.</summary>
public sealed class GetMyOffersHandler(IRepository<Offer> offers, IRepository<Listing> listings, IGeographyRepository geography, IUserDirectory users)
    : IQueryHandler<GetMyOffersQuery, IReadOnlyList<CarrierOfferDto>>
{
    /// <summary>Yalnız jetondaki taşımacının, kendi geçmişinden silmediği teklifler döner.</summary>
    public async Task<IReadOnlyList<CarrierOfferDto>> HandleAsync(GetMyOffersQuery query, CancellationToken cancellationToken = default)
    {
        var mine = await offers.ListAsync(o => o.CarrierId == query.CarrierId && !o.HiddenByCarrier, asNoTracking: true, cancellationToken);
        var ids = mine.Select(o => o.ListingId).Distinct().ToList();
        var listingMap = (await listings.ListAsync(l => ids.Contains(l.Id), asNoTracking: true, cancellationToken)).ToDictionary(l => l.Id);
        var cities = (await geography.ListCitiesAsync(cancellationToken)).ToDictionary(c => c.Id, c => c.Name);
        // İlçe adları ve ilanı açan Yük Veren'in adı (ilan sahibi = ilanı veren firma/kişi).
        var districts = await Listings.CreateListingHandler.DistrictNamesAsync(geography, listingMap.Values, cancellationToken);
        var shippers = await users.GetFullNamesAsync(listingMap.Values.Select(l => l.ShipperId), cancellationToken);

        return mine.OrderByDescending(o => o.DecidedAt ?? o.CreatedAt)
            .Where(o => listingMap.ContainsKey(o.ListingId))
            .Select(o =>
            {
                var l = listingMap[o.ListingId];
                return new CarrierOfferDto(o.Id, l.Id, l.Title, cities[l.FromCityId], districts[l.FromDistrictId],
                    cities[l.ToCityId], districts[l.ToDistrictId], shippers.GetValueOrDefault(l.ShipperId, "Yük Veren"),
                    l.WeightKg, l.PickupDate, o.Amount, o.Note,
                    o.Status, IsNew: o.Status != OfferStatus.Pending && !o.CarrierSeen, o.CreatedAt, o.DecidedAt);
            }).ToList();
    }
}

/// <summary>Yük Veren'in karara bağladığı (kabul/red) teklifler: "eski teklifler" bölümü.</summary>
public sealed class GetShipperOfferHistoryHandler(IRepository<Offer> offers, IRepository<Listing> listings, IUserDirectory users, IGeographyRepository geography)
    : IQueryHandler<GetShipperOfferHistoryQuery, IReadOnlyList<ShipperOfferHistoryDto>>
{
    /// <summary>Yalnız jetondaki yük verenin ilanlarına gelen, karar verilmiş ve silinmemiş teklifler.</summary>
    public async Task<IReadOnlyList<ShipperOfferHistoryDto>> HandleAsync(GetShipperOfferHistoryQuery query, CancellationToken cancellationToken = default)
    {
        var myListings = (await listings.ListAsync(l => l.ShipperId == query.ShipperId, asNoTracking: true, cancellationToken)).ToDictionary(l => l.Id);
        var listingIds = myListings.Keys.ToList();
        var decided = await offers.ListAsync(
            o => listingIds.Contains(o.ListingId) && o.Status != OfferStatus.Pending && !o.HiddenByShipper,
            asNoTracking: true, cancellationToken);
        var names = await users.GetFullNamesAsync(decided.Select(o => o.CarrierId), cancellationToken);
        var cities = (await geography.ListCitiesAsync(cancellationToken)).ToDictionary(c => c.Id, c => c.Name);
        var districts = await Listings.CreateListingHandler.DistrictNamesAsync(geography, myListings.Values, cancellationToken);

        return decided.OrderByDescending(o => o.DecidedAt)
            .Select(o =>
            {
                var l = myListings[o.ListingId];
                return new ShipperOfferHistoryDto(o.Id, l.Id, l.Title, cities[l.FromCityId], districts[l.FromDistrictId],
                    cities[l.ToCityId], districts[l.ToDistrictId], l.WeightKg, l.PickupDate,
                    names.GetValueOrDefault(o.CarrierId, "Taşımacı"), o.Amount, o.Note, o.Status, o.DecidedAt);
            }).ToList();
    }
}

/// <summary>Karara bağlanmış teklifi kullanıcının KENDİ geçmişinden gizler (karşı taraf görmeye devam eder).</summary>
public sealed class HideOfferHandler(IRepository<Offer> offers, IRepository<Listing> listings, IUnitOfWork unitOfWork)
    : ICommandHandler<HideOfferCommand, bool>
{
    /// <summary>Teklif kullanıcıya ait değilse 404; bekleyen teklifse 409 (önce karar verilmeli).</summary>
    public async Task<bool> HandleAsync(HideOfferCommand command, CancellationToken cancellationToken = default)
    {
        var offer = await offers.GetByIdAsync(command.OfferId, asNoTracking: false, cancellationToken)
            ?? throw new NotFoundException("Teklif bulunamadı.");

        if (command.IsCarrier)
        {
            if (offer.CarrierId != command.UserId) throw new NotFoundException("Teklif bulunamadı.");
        }
        else
        {
            var listing = await listings.GetByIdAsync(offer.ListingId, asNoTracking: true, cancellationToken);
            if (listing is null || listing.ShipperId != command.UserId) throw new NotFoundException("Teklif bulunamadı.");
        }

        if (offer.Status == OfferStatus.Pending)
            throw new ConflictException("Bekleyen teklif silinemez; önce karar verilmeli.");

        if (command.IsCarrier) offer.HiddenByCarrier = true; else offer.HiddenByShipper = true;
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return true;
    }
}

/// <summary>Taşımacı'nın görmediği karar sayısı (anasayfadaki rozet için).</summary>
public sealed class GetUnseenCountHandler(IRepository<Offer> offers) : IQueryHandler<GetUnseenCountQuery, UnseenCountDto>
{
    /// <summary>Karar verilmiş, görülmemiş ve silinmemiş teklif sayısı.</summary>
    public async Task<UnseenCountDto> HandleAsync(GetUnseenCountQuery query, CancellationToken cancellationToken = default) =>
        new(await offers.CountAsync(o => o.CarrierId == query.CarrierId && o.Status != OfferStatus.Pending && !o.CarrierSeen && !o.HiddenByCarrier, cancellationToken));
}

/// <summary>Karar bildirimlerini görüldü yapar (taşımacı "Tekliflerim"i açınca).</summary>
public sealed class MarkSeenHandler(IRepository<Offer> offers, IUnitOfWork unitOfWork) : ICommandHandler<MarkSeenCommand, bool>
{
    /// <summary>Taşımacı'nın görülmemiş kararlarını CarrierSeen=true yapar.</summary>
    public async Task<bool> HandleAsync(MarkSeenCommand command, CancellationToken cancellationToken = default)
    {
        var unseen = await offers.ListAsync(o => o.CarrierId == command.CarrierId && o.Status != OfferStatus.Pending && !o.CarrierSeen,
            asNoTracking: false, cancellationToken);
        foreach (var o in unseen) o.CarrierSeen = true;
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return true;
    }
}
