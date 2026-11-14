using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Application.Notifications;
using Yukum.Domain.Listings;
using Yukum.Domain.Notifications;

namespace Yukum.Application.Listings;

/// <summary>
/// İlanı yayından kaldırır. İlan "Kaldırıldı" olur (hiçbir listede görünmez). Bekleyen ve kabul edilmiş teklifler "İptal" olur:
/// taşımacılar bunu Tekliflerim'de görür ve bildirim rozeti alır, sohbet iki tarafta yazmaya kapanır. İlan sahibi bu teklifleri
/// kendi listesinden zaten kaldırmış sayılır (ilanı kendisi kaldırdı).
/// </summary>
public sealed class CancelListingHandler(
    IRepository<Listing> listings,
    IRepository<Offer> offers,
    IRepository<Notification> notifications,
    IUnitOfWork unitOfWork,
    TimeProvider time) : ICommandHandler<CancelListingCommand, bool>
{
    /// <summary>İlan yoksa ya da başkasınınsa 404; zaten tamamlanmış/kaldırılmışsa 409.</summary>
    public async Task<bool> HandleAsync(CancelListingCommand command, CancellationToken cancellationToken = default)
    {
        var listing = await listings.GetByIdAsync(command.ListingId, asNoTracking: false, cancellationToken);
        if (listing is null || listing.ShipperId != command.ShipperId)
            throw new NotFoundException("İlan bulunamadı.");   // başkasının ilanının varlığı sızdırılmaz

        if (listing.Status is ListingStatus.Completed or ListingStatus.Cancelled)
            throw new ConflictException("Bu ilan zaten tamamlanmış ya da kaldırılmış.");

        // KABUL EDİLMİŞ TEKLİF VARKEN KALDIRILAMAZ (15 Kasım, yönetici kuralı: "teklif kabul edilince ilan silinmemeli, teslim olmadan silinmemeli").
        //   Önceden kabul edilmiş iş de iptal ediliyor, taşımacının yola çıkmış işi bir anda düşüyordu.
        //   Teslim edilmemiş iş → kaldırılamaz. Teslim edilmiş iş → kaldırma yerine "İşi Bitir ve Sil" (iş tamamlanır, puan ve geçmiş korunur).
        //   Ilan Assigned iken düzenleme zaten UpdateListingHandler'da engelli.
        if (listing.Status == ListingStatus.Assigned)
        {
            var delivered = await offers.AnyAsync(
                o => o.ListingId == listing.Id && o.Status == OfferStatus.Accepted && o.Stage == JobStage.Delivered, cancellationToken);
            throw new ConflictException(delivered
                ? "Yük teslim edildi. İlanı kaldırmak yerine sohbetten \"İşi Bitir ve Sil\" ile işi tamamla."
                : "Bu ilanda kabul edilmiş bir teklif var; yük teslim edilmeden ilan kaldırılamaz.");
        }

        listing.Status = ListingStatus.Cancelled;

        // Bekleyen teklifler iptal olur; reddedilenler olduğu gibi kalır. (Kabul edilmiş teklif buraya gelemez: yukarıda engellendi.)
        var now = time.GetUtcNow().UtcDateTime;
        var live = await offers.ListAsync(
            o => o.ListingId == listing.Id && (o.Status == OfferStatus.Pending || o.Status == OfferStatus.Accepted),
            asNoTracking: false, cancellationToken);
        foreach (var offer in live)
        {
            offer.Status = OfferStatus.Cancelled;
            offer.DecidedAt = now;
            offer.CarrierSeen = false;      // taşımacıda "Yeni" rozeti
            offer.HiddenByShipper = true;   // ilan sahibi ilanı kendisi kaldırdı, teklifler onun geçmişine düşmez
            notifications.Add(NotificationFactory.ListingCancelled(offer.CarrierId, listing, offer.Id));
        }

        await unitOfWork.SaveChangesAsync(cancellationToken);
        return true;
    }
}
