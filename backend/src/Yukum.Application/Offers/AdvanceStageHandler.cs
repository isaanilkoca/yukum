using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Domain.Listings;

namespace Yukum.Application.Offers;

/// <summary>Taşımacı kabul edilmiş işin aşamasını bir sonrakine ilerletir (alındı → yolda → teslim edildi). Aşama atlanmaz, geri alınmaz.</summary>
public sealed class AdvanceStageHandler(IRepository<Offer> offers, IUnitOfWork unitOfWork) : ICommandHandler<AdvanceStageCommand, OfferStageDto>
{
    // FONKSİYON ROLÜ: API'NİN İŞ MANTIĞI | OffersController.Advance çağırır: sahiplik + durum kontrolü, aşamayı +1 yapar, DB'ye yazar
    /// <summary>Başkasının/olmayan teklif 404; kabul edilmemiş iş ya da zaten teslim edilmiş iş 409.</summary>
    public async Task<OfferStageDto> HandleAsync(AdvanceStageCommand command, CancellationToken cancellationToken = default)
    {
        var offer = await offers.GetByIdAsync(command.OfferId, asNoTracking: false, cancellationToken);
        if (offer is null || offer.CarrierId != command.CarrierId)
            throw new NotFoundException("Teklif bulunamadı.");
        if (offer.Status != OfferStatus.Accepted)
            throw new ConflictException("Yalnız kabul edilmiş işin aşaması ilerletilebilir.");
        if (offer.Stage == JobStage.Delivered)
            throw new ConflictException("Yük zaten teslim edildi.");

        offer.Stage += 1; // enum sıralı: NotStarted(0) → PickedUp(1) → InTransit(2) → Delivered(3)
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return new OfferStageDto(offer.Id, offer.Stage);
    }
}
