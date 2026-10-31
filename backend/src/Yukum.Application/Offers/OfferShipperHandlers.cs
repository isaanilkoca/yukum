using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Domain.Listings;

namespace Yukum.Application.Offers;

/// <summary>Yük Veren'in kendi ilanına gelen teklifleri getirir (düşük tutar üstte).</summary>
public sealed class GetListingOffersHandler(IRepository<Listing> listings, IRepository<Offer> offers, IUserDirectory users)
    : IQueryHandler<GetListingOffersQuery, IReadOnlyList<ListingOfferDto>>
{
    /// <summary>İlan yoksa ya da başkasınınsa NotFoundException (404; başkasının ilanının varlığı sızdırılmaz).</summary>
    public async Task<IReadOnlyList<ListingOfferDto>> HandleAsync(GetListingOffersQuery query, CancellationToken cancellationToken = default)
    {
        var listing = await listings.GetByIdAsync(query.ListingId, asNoTracking: true, cancellationToken);
        if (listing is null || listing.ShipperId != query.ShipperId)
            throw new NotFoundException("İlan bulunamadı.");

        var list = await offers.ListAsync(o => o.ListingId == query.ListingId && !o.HiddenByShipper, asNoTracking: true, cancellationToken);
        var names = await users.GetFullNamesAsync(list.Select(o => o.CarrierId), cancellationToken);

        return list.OrderBy(o => o.Amount)
            .Select(o => new ListingOfferDto(o.Id, names.GetValueOrDefault(o.CarrierId, "Taşımacı"), o.Amount, o.Note, o.Status, o.CreatedAt))
            .ToList();
    }
}

/// <summary>Yük Veren teklifi kabul eder ya da reddeder. Kabulde ilan atanır, diğer bekleyen teklifler reddedilir.</summary>
public sealed class DecideOfferHandler(IRepository<Listing> listings, IRepository<Offer> offers, IUnitOfWork unitOfWork, TimeProvider time)
    : ICommandHandler<DecideOfferCommand, OfferDto>
{
    /// <summary>Teklif/ilan yoksa ya da ilan başkasınınsa 404; teklif bekleyen ya da ilan açık değilse 409.</summary>
    public async Task<OfferDto> HandleAsync(DecideOfferCommand command, CancellationToken cancellationToken = default)
    {
        var offer = await offers.GetByIdAsync(command.OfferId, asNoTracking: false, cancellationToken)
            ?? throw new NotFoundException("Teklif bulunamadı.");
        var listing = await listings.GetByIdAsync(offer.ListingId, asNoTracking: false, cancellationToken);
        if (listing is null || listing.ShipperId != command.ShipperId)
            throw new NotFoundException("Teklif bulunamadı.");

        if (listing.Status != ListingStatus.Open)
            throw new ConflictException("Bu ilan için karar zaten verilmiş.");
        if (offer.Status != OfferStatus.Pending)
            throw new ConflictException("Bu teklif için karar zaten verilmiş.");

        var now = time.GetUtcNow().UtcDateTime; // karar anı (UTC)
        offer.DecidedAt = now;
        offer.CarrierSeen = false; // taşımacıda "Yeni" rozeti çıkar

        if (command.Accept)
        {
            offer.Status = OfferStatus.Accepted;
            listing.Status = ListingStatus.Assigned;
            // Aynı ilandaki diğer bekleyen teklifler otomatik reddedilir.
            var others = await offers.ListAsync(o => o.ListingId == listing.Id && o.Id != offer.Id && o.Status == OfferStatus.Pending,
                asNoTracking: false, cancellationToken);
            foreach (var other in others)
            {
                other.Status = OfferStatus.Rejected;
                other.DecidedAt = now;
                other.CarrierSeen = false;
            }
        }
        else
        {
            offer.Status = OfferStatus.Rejected;
        }

        await unitOfWork.SaveChangesAsync(cancellationToken);
        return new OfferDto(offer.Id, offer.ListingId, offer.Amount, offer.Note, offer.Status);
    }
}
