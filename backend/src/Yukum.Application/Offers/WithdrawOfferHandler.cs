using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Domain.Listings;

namespace Yukum.Application.Offers;

/// <summary>Taşımacı kendi BEKLEYEN teklifini geri çeker. Teklif silinmez, durumu Geri çekildi olur (Taşımacı geçmişte görür, Yük Veren görmez).</summary>
public sealed class WithdrawOfferHandler(IRepository<Offer> offers, IUnitOfWork unitOfWork) : ICommandHandler<WithdrawOfferCommand, OfferDto>
{
    // FONKSİYON ROLÜ: API'NİN İŞ MANTIĞI | OffersController.Withdraw çağırır: sahiplik + durum kontrolü yapar, durumu Withdrawn yapar, DB'ye yazar
    /// <summary>Başkasının/olmayan teklif 404 (varlığı sızdırılmaz); bekleyen olmayan teklif 409.</summary>
    public async Task<OfferDto> HandleAsync(WithdrawOfferCommand command, CancellationToken cancellationToken = default)
    {
        var offer = await offers.GetByIdAsync(command.OfferId, asNoTracking: false, cancellationToken);
        if (offer is null || offer.CarrierId != command.CarrierId)
            throw new NotFoundException("Teklif bulunamadı.");
        if (offer.Status != OfferStatus.Pending)
            throw new ConflictException("Yalnız bekleyen teklif geri çekilebilir.");

        offer.Status = OfferStatus.Withdrawn;
        offer.DecidedAt = DateTime.UtcNow; // geçmiş listesi "karar/işlem anı"na göre sıralanır
        offer.CarrierSeen = true; // kararı kendisi verdi: "Yeni" rozeti çıkmaz

        await unitOfWork.SaveChangesAsync(cancellationToken);
        return new OfferDto(offer.Id, offer.ListingId, offer.Amount, offer.Note, offer.Status);
    }
}
