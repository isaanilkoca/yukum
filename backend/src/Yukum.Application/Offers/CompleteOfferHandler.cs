using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Application.Notifications;
using Yukum.Domain.Listings;
using Yukum.Domain.Notifications;

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
    IRepository<Notification> notifications,
    ICarrierDirectory carriers,
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
        if (offer.Stage != JobStage.Delivered)
            throw new ConflictException("Önce yük teslim edilmeli.");   // aşama akışı: alındı → yolda → teslim edildi → ancak sonra bitir

        // Durum iki taraf için de değişir: sohbet iki tarafta kilitlenir.
        offer.Status = OfferStatus.Completed;
        listing.Status = ListingStatus.Completed;

        // Taşımacı bitirmediyse ona "Yeni" bildirimi (rozet) gider.
        if (!isCarrier) offer.CarrierSeen = false;

        // Karşı tarafa haber: bitiren Taşımacı ise Yük Veren'e, bitiren Yük Veren ise Taşımacı'ya
        notifications.Add(NotificationFactory.JobCompleted(isCarrier ? listing.ShipperId : offer.CarrierId, listing, offer.Id));

        // Silme yalnız bitirenin tarafında: teklif geçmişinden ve mesajlar.
        if (isCarrier) offer.HiddenByCarrier = true; else offer.HiddenByShipper = true;
        var mine = await messages.ListAsync(m => m.OfferId == offer.Id, asNoTracking: false, cancellationToken);
        foreach (var m in mine)
        {
            if (isCarrier) m.HiddenByCarrier = true; else m.HiddenByShipper = true;
        }

        // Tamamlanan iş sayacı + durum değişiklikleri TEK işlemde (biri olmazsa ikisi de olmaz)
        await unitOfWork.ExecuteInTransactionAsync(async ct =>
        {
            await unitOfWork.SaveChangesAsync(ct);
            await carriers.AddCompletedJobAsync(offer.CarrierId, ct);
        }, cancellationToken);
        return new OfferDto(offer.Id, offer.ListingId, offer.Amount, offer.Note, offer.Status);
    }
}
