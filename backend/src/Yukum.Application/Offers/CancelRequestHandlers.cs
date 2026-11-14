using FluentValidation;
using FluentValidation.Results;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Application.Notifications;
using Yukum.Domain.Listings;
using Yukum.Domain.Notifications;

namespace Yukum.Application.Offers;

// ─── KARŞILIKLI İPTAL (15 Kasım) ─────────────────────────────────────────────
// SENARYO: teklif kabul edildi, ama iş yapılamayacak (ör. araç bozuldu). Tek taraf işi bozamaz (ilan kaldırma kuralı:
//   CancelListingHandler). Bir taraf İPTAL TALEP EDER, karşı taraf ONAYLAR ya da REDDEDER; talep eden yanıt gelmeden GERİ ÇEKEBİLİR.
// KURALLAR:
//   • Yalnız kabul edilmiş (Accepted) ve TESLİM EDİLMEMİŞ işte. Teslimden sonra yol "İşi Bitir".
//   • Aynı anda tek açık talep. Talep açıkken iş aynen sürer.
//   • Onayda: teklif Cancelled + MutuallyCancelled; ilanın ne olacağını HER ZAMAN Yük Veren seçer (kullanıcı kararı):
//       talebi Yük Veren açtıysa talep anında (ReopenListing), Taşımacı açtıysa Yük Veren onaylarken seçer.
//       Yeniden yayınla → ilan Open (yeni teklif alır) | kaldır → ilan Cancelled.
//   • Karşılıklı iptal sayısı profilde GÖSTERİLMEZ (kullanıcı kararı).
// DOĞRULAMA: FluentValidation.ValidationException → API 400 + Türkçe alan mesajı (diğer formlarla aynı biçim).
// GÜVENLİK: kullanıcı ya teklifin Taşımacısı ya ilanın Yük Veren'i olmalı; değilse 404 (başkasının işinin varlığı sızdırılmaz).

/// <summary>İptal talebi açar.</summary>
public sealed class RequestCancelHandler(IRepository<Offer> offers, IRepository<Listing> listings, IRepository<Notification> notifications,
    IUserDirectory users, IUnitOfWork unitOfWork, TimeProvider time) : ICommandHandler<RequestCancelCommand, bool>
{
    public async Task<bool> HandleAsync(RequestCancelCommand command, CancellationToken cancellationToken = default)
    {
        var (offer, listing, isShipper) = await CancelRequestHandlers.LoadAsync(offers, listings, command.OfferId, command.UserId, cancellationToken);
        CancelRequestHandlers.EnsureActiveJob(offer);
        if (offer.CancelRequestedBy is not null)
            throw new ConflictException("Bu iş için zaten açık bir iptal talebi var.");

        var reason = command.Reason?.Trim();
        if (string.IsNullOrEmpty(reason)) throw new ValidationException([new ValidationFailure("Reason", "İptal nedenini seç.")]);
        if (reason.Length > 60) throw new ValidationException([new ValidationFailure("Reason", "İptal nedeni en fazla 60 karakter olabilir.")]);
        var note = string.IsNullOrWhiteSpace(command.Note) ? null : command.Note.Trim();
        if (note?.Length > 300) throw new ValidationException([new ValidationFailure("Note", "Açıklama en fazla 300 karakter olabilir.")]);

        offer.CancelRequestedBy = command.UserId;
        offer.CancelReason = reason;
        offer.CancelNote = note;
        offer.CancelRequestedAt = time.GetUtcNow().UtcDateTime;
        offer.CancelReopenListing = isShipper ? command.ReopenListing ?? true : null; // Yük Veren'in seçimi (varsayılan: yeniden yayınla)

        var requesterName = (await users.GetFullNamesAsync([command.UserId], cancellationToken)).GetValueOrDefault(command.UserId, isShipper ? "Yük Veren" : "Taşımacı");
        var other = isShipper ? offer.CarrierId : listing.ShipperId;
        notifications.Add(NotificationFactory.CancelRequested(other, listing, offer.Id, requesterName, reason));
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return true;
    }
}

/// <summary>Karşı taraf iptal talebini onaylar ya da reddeder.</summary>
public sealed class RespondCancelHandler(IRepository<Offer> offers, IRepository<Listing> listings, IRepository<Notification> notifications,
    IUnitOfWork unitOfWork, TimeProvider time) : ICommandHandler<RespondCancelCommand, bool>
{
    public async Task<bool> HandleAsync(RespondCancelCommand command, CancellationToken cancellationToken = default)
    {
        var (offer, listing, isShipper) = await CancelRequestHandlers.LoadAsync(offers, listings, command.OfferId, command.UserId, cancellationToken);
        if (offer.CancelRequestedBy is null)
            throw new ConflictException("Bu iş için açık bir iptal talebi yok.");
        if (offer.CancelRequestedBy == command.UserId)
            throw new ConflictException("Kendi talebini onaylayamazsın; karşı tarafın yanıtını bekle ya da talebi geri çek.");
        var requester = offer.CancelRequestedBy.Value;

        if (command.Approve)
        {
            CancelRequestHandlers.EnsureActiveJob(offer); // talep açıkken yük teslim edildiyse artık iptal değil "İşi Bitir"
            var reopen = isShipper ? command.ReopenListing ?? true : offer.CancelReopenListing ?? true;
            offer.Status = OfferStatus.Cancelled;
            offer.MutuallyCancelled = true;
            offer.DecidedAt = time.GetUtcNow().UtcDateTime;
            offer.CarrierSeen = false; // Taşımacıda "Yeni" rozeti
            listing.Status = reopen ? ListingStatus.Open : ListingStatus.Cancelled;
            notifications.Add(NotificationFactory.CancelApproved(requester, listing, offer.Id));
        }
        else
        {
            notifications.Add(NotificationFactory.CancelRejected(requester, listing, offer.Id));
        }
        CancelRequestHandlers.Clear(offer);
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return true;
    }
}

/// <summary>Talep eden, karşı taraf yanıtlamadan talebini geri çeker.</summary>
public sealed class WithdrawCancelHandler(IRepository<Offer> offers, IRepository<Listing> listings, IUnitOfWork unitOfWork)
    : ICommandHandler<WithdrawCancelCommand, bool>
{
    public async Task<bool> HandleAsync(WithdrawCancelCommand command, CancellationToken cancellationToken = default)
    {
        var (offer, _, _) = await CancelRequestHandlers.LoadAsync(offers, listings, command.OfferId, command.UserId, cancellationToken);
        if (offer.CancelRequestedBy != command.UserId)
            throw new ConflictException("Geri çekilecek bir iptal talebin yok.");
        CancelRequestHandlers.Clear(offer);
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return true;
    }
}

/// <summary>Ortak yardımcılar.</summary>
public static class CancelRequestHandlers
{
    /// <summary>Teklif + ilanı yükler; kullanıcının taraf olup olmadığını denetler. isShipper: kullanıcı ilanın sahibi mi.</summary>
    public static async Task<(Offer offer, Listing listing, bool isShipper)> LoadAsync(IRepository<Offer> offers, IRepository<Listing> listings,
        Guid offerId, Guid userId, CancellationToken cancellationToken)
    {
        var offer = await offers.GetByIdAsync(offerId, asNoTracking: false, cancellationToken) ?? throw new NotFoundException("Teklif bulunamadı.");
        var listing = await listings.GetByIdAsync(offer.ListingId, asNoTracking: false, cancellationToken) ?? throw new NotFoundException("Teklif bulunamadı.");
        var isShipper = listing.ShipperId == userId;
        if (!isShipper && offer.CarrierId != userId) throw new NotFoundException("Teklif bulunamadı.");
        return (offer, listing, isShipper);
    }

    /// <summary>İptal yalnız kabul edilmiş ve teslim edilmemiş işte.</summary>
    public static void EnsureActiveJob(Offer offer)
    {
        if (offer.Status != OfferStatus.Accepted)
            throw new ConflictException("Yalnız kabul edilmiş bir iş için iptal talep edilebilir.");
        if (offer.Stage == JobStage.Delivered)
            throw new ConflictException("Yük teslim edildi; iptal yerine \"İşi Bitir\" ile tamamla.");
    }

    public static void Clear(Offer offer)
    {
        offer.CancelRequestedBy = null; offer.CancelReason = null; offer.CancelNote = null;
        offer.CancelRequestedAt = null; offer.CancelReopenListing = null;
    }

    /// <summary>Listelerdeki görünüm: açık talep yoksa null.</summary>
    public static CancelRequestDto? ToDto(Offer offer, Guid viewerId) =>
        offer.CancelRequestedBy is { } by && offer.CancelReason is { } reason
            ? new CancelRequestDto(by == viewerId, reason, offer.CancelNote, offer.CancelRequestedAt ?? DateTime.UtcNow)
            : null;
}
