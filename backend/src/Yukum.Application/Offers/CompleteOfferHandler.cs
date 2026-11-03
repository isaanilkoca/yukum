using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Domain.Listings;

namespace Yukum.Application.Offers;

/// <summary>
/// "İşi bitir ve sil": kabul edilmiş işi tamamlar. Durum iki tarafta da Tamamlandı olur (sohbet iki tarafta yazmaya kapanır),
/// ama silme yalnız bitirenin görünümünde olur: teklifi geçmişinden gizler ve mesajlarını gizler. Karşı taraf teklifi
/// Tamamlandı olarak görmeye devam eder, istediğinde kendisi siler.
/// </summary>
public sealed class CompleteOfferHandler(
    IRepository<Offer> offers,
    IRepository<Listing> listings,
    IRepository<Message> messages,
    IUnitOfWork unitOfWork) : ICommandHandler<CompleteOfferCommand, OfferDto>
{
    /// <summary>Taraf olmayana 404; kabul edilmiş olmayan (bekleyen, reddedilmiş, zaten tamamlanmış) işe 409.</summary>
    public async Task<OfferDto> HandleAsync(CompleteOfferCommand command, CancellationToken cancellationToken = default)
    {
        var offer = await offers.GetByIdAsync(command.OfferId, asNoTracking: false, cancellationToken)
            ?? throw new NotFoundException("Teklif bulunamadı.");
        var listing = await listings.GetByIdAsync(offer.ListingId, asNoTracking: false, cancellationToken)
            ?? throw new NotFoundException("Teklif bulunamadı.");

        var isCarrier = offer.CarrierId == command.UserId;
        var isShipper = listing.ShipperId == command.UserId;
        if (!isCarrier && !isShipper) throw new NotFoundException("Teklif bulunamadı.");   // taraf değil: varlığı sızdırılmaz

        if (offer.Status != OfferStatus.Accepted)
            throw new ConflictException("Yalnız kabul edilmiş iş tamamlanabilir.");

        // Durum iki taraf için de değişir: sohbet iki tarafta kilitlenir.
        offer.Status = OfferStatus.Completed;
        listing.Status = ListingStatus.Completed;

        // Taşımacı bitirmediyse ona "Yeni" bildirimi (rozet) gider.
        if (!isCarrier) offer.CarrierSeen = false;

        // Silme yalnız bitirenin tarafında: teklif geçmişinden ve mesajlar.
        if (isCarrier) offer.HiddenByCarrier = true; else offer.HiddenByShipper = true;
        var mine = await messages.ListAsync(m => m.OfferId == offer.Id, asNoTracking: false, cancellationToken);
        foreach (var m in mine)
        {
            if (isCarrier) m.HiddenByCarrier = true; else m.HiddenByShipper = true;
        }

        await unitOfWork.SaveChangesAsync(cancellationToken);
        return new OfferDto(offer.Id, offer.ListingId, offer.Amount, offer.Note, offer.Status);
    }
}
