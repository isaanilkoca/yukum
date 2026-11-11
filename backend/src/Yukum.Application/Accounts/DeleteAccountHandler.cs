using FluentValidation;
using FluentValidation.Results;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Application.Notifications;
using Yukum.Domain.Listings;
using Yukum.Domain.Notifications;

namespace Yukum.Application.Accounts;

/// <summary>
/// Kullanıcının kendi hesabını silmesi (Apple + KVKK "silme hakkı"). Kayıtlar fiziksel silinmez, kişisel veri ANONİMLEŞTİRİLİR:
/// karşı tarafların geçmişi (teklif, sohbet, puan) bozulmaz ama kişi tanınamaz hale gelir.
/// </summary>
public sealed class DeleteAccountHandler(
    IValidator<DeleteAccountCommand> validator,
    IAccountService accounts,
    IRepository<Listing> listings,
    IRepository<Offer> offers,
    IRepository<Notification> notifications,
    IEngagementRepository engagement,
    INotificationRepository notificationData,
    IDeviceTokenRepository deviceTokens,
    IUnitOfWork unitOfWork,
    TimeProvider time) : ICommandHandler<DeleteAccountCommand, bool>
{
    // FONKSİYON ROLÜ: API'NİN İŞ MANTIĞI | AccountController çağırır: şifreyi doğrular, aktif iş var mı bakar, açık ilan/teklifleri temizler,
    // favori/görüntülenme kayıtlarını siler ve hesabı anonimleştirir. HEPSİ TEK İŞLEMDE (biri başarısızsa hiçbiri olmaz)
    /// <summary>Şifre yanlışsa 400; aktif işi (kabul edilmiş, bitmemiş) varsa 409.</summary>
    public async Task<bool> HandleAsync(DeleteAccountCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);

        // 401 DEĞİL 400: iOS 401'i "oturum bitti" sayıp çıkış yaptırır; yanlış şifre oturumu bitirmemeli.
        if (!await accounts.VerifyPasswordAsync(command.UserId, command.Password!, cancellationToken))
            throw new ValidationException([new ValidationFailure("password", "Şifre hatalı.")]);

        // Aktif iş: kabul edilmiş ama tamamlanmamış. Karşı tarafı yarı yolda bırakmamak için önce bitirilmeli ya da iptal edilmeli.
        var hasActiveJob =
            await listings.AnyAsync(l => l.ShipperId == command.UserId && l.Status == ListingStatus.Assigned, cancellationToken)
            || await offers.AnyAsync(o => o.CarrierId == command.UserId && o.Status == OfferStatus.Accepted, cancellationToken);
        if (hasActiveJob)
            throw new ConflictException("Devam eden bir işin var. Önce işi tamamla ya da ilanı iptal et, sonra hesabını silebilirsin.");

        var now = time.GetUtcNow().UtcDateTime;
        await unitOfWork.ExecuteInTransactionAsync(async ct =>
        {
            // Yük Veren: açık ilanları kaldırılır, üzerindeki bekleyen teklifler iptal olur (Taşımacı "İlan kaldırıldı" görür).
            var open = await listings.ListAsync(l => l.ShipperId == command.UserId && l.Status == ListingStatus.Open, asNoTracking: false, ct);
            foreach (var listing in open) listing.Status = ListingStatus.Cancelled;
            var openIds = open.Select(l => l.Id).ToList();
            foreach (var offer in await offers.ListAsync(o => openIds.Contains(o.ListingId) && o.Status == OfferStatus.Pending, asNoTracking: false, ct))
            {
                offer.Status = OfferStatus.Cancelled; offer.DecidedAt = now; offer.CarrierSeen = false; offer.HiddenByShipper = true;
                notifications.Add(NotificationFactory.ListingCancelled(offer.CarrierId, open.First(l => l.Id == offer.ListingId), offer.Id)); // Taşımacı "İlan kaldırıldı" bildirimi alır
            }

            // Taşımacı: bekleyen teklifleri geri çekilir (ilan sahibi artık cevaplanamaz bir teklif görmez).
            foreach (var offer in await offers.ListAsync(o => o.CarrierId == command.UserId && o.Status == OfferStatus.Pending, asNoTracking: false, ct))
            {
                offer.Status = OfferStatus.Withdrawn; offer.DecidedAt = now; offer.CarrierSeen = true;
            }

            await unitOfWork.SaveChangesAsync(ct);
            await engagement.DeleteUserDataAsync(command.UserId, ct);   // favoriler + görüntülenme izleri: kişisel davranış verisi, tamamen silinir
            await notificationData.DeleteUserDataAsync(command.UserId, ct); // kendi bildirimleri de silinir (karşı taraflara giden bildirimler kalır)
            await deviceTokens.DeleteUserDataAsync(command.UserId, ct);     // telefon push adresleri: silinen hesaba bildirim gitmez
            await accounts.AnonymizeAsync(command.UserId, ct);
        }, cancellationToken);
        return true;
    }
}
