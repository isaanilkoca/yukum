using System.Globalization;
using Yukum.Domain.Listings;
using Yukum.Domain.Notifications;

namespace Yukum.Application.Notifications;

/// <summary>
/// Bildirim metinlerinin TEK yeri: handler'lar yalnız "ne oldu, kime" der, yazı burada. Metinler karşı tarafın kişisel bilgisini (ad, telefon) içermez, ilan başlığı ve tutar yeter.
/// Fonksiyonlar yalnız nesne üretir; kaydetmek handler'ın işidir (olayla aynı SaveChanges'te yazılır).
/// </summary>
public static class NotificationFactory
{
    private static readonly CultureInfo Tr = new("tr-TR");

    /// <summary>Yük Veren'e: ilanına teklif geldi (updated=true: Taşımacı tutarı değiştirdi).</summary>
    public static Notification OfferReceived(Guid shipperId, Listing listing, Guid offerId, decimal amount, bool updated) => New(
        shipperId, NotificationType.OfferReceived, updated ? "Teklif güncellendi" : "Yeni teklif",
        $"“{listing.Title}” ilanı için {amount.ToString("N0", Tr)} ₺ teklif {(updated ? "güncellendi" : "geldi")}.", listing.Id, offerId);

    /// <summary>Taşımacı'ya: teklifi kabul edildi.</summary>
    public static Notification OfferAccepted(Guid carrierId, Listing listing, Guid offerId) => New(
        carrierId, NotificationType.OfferAccepted, "Teklifin kabul edildi", $"“{listing.Title}” ilanı için teklifin kabul edildi.", listing.Id, offerId);

    /// <summary>Taşımacı'ya: teklifi reddedildi. otherChosen: ilan başka bir teklife verildi.</summary>
    public static Notification OfferRejected(Guid carrierId, Listing listing, Guid offerId, bool otherChosen) => New(
        carrierId, NotificationType.OfferRejected, "Teklifin reddedildi",
        otherChosen ? $"“{listing.Title}” ilanı başka bir teklife verildi." : $"“{listing.Title}” ilanı için teklifin reddedildi.", listing.Id, offerId);

    /// <summary>Yük Veren'e: işin aşaması değişti.</summary>
    public static Notification StageChanged(Guid shipperId, Listing listing, Guid offerId, JobStage stage) => New(
        shipperId, NotificationType.JobStageChanged, stage switch
        {
            JobStage.PickedUp => "Yük alındı",
            JobStage.InTransit => "Yük yolda",
            JobStage.Delivered => "Yük teslim edildi",
            _ => "İş güncellendi"
        }, $"“{listing.Title}” işi için güncelleme var.", listing.Id, offerId);

    /// <summary>Karşı tarafa: iş tamamlandı.</summary>
    public static Notification JobCompleted(Guid userId, Listing listing, Guid offerId) => New(
        userId, NotificationType.JobCompleted, "İş tamamlandı", $"“{listing.Title}” işi tamamlandı.", listing.Id, offerId);

    /// <summary>Taşımacı'ya: yeni puan aldı.</summary>
    public static Notification ReviewReceived(Guid carrierId, Listing listing, Guid offerId, int rating) => New(
        carrierId, NotificationType.ReviewReceived, "Yeni puan aldın", $"“{listing.Title}” işi için {rating}/5 puan aldın.", listing.Id, offerId);

    /// <summary>Taşımacı'ya: teklif verdiği ilan kaldırıldı.</summary>
    public static Notification ListingCancelled(Guid carrierId, Listing listing, Guid offerId) => New(
        carrierId, NotificationType.ListingCancelled, "İlan kaldırıldı", $"“{listing.Title}” ilanı yayından kaldırıldı.", listing.Id, offerId);

    // ─── Karşılıklı iptal (15 Kasım) ───
    public static Notification CancelRequested(Guid userId, Listing listing, Guid offerId, string requester, string reason) => New(
        userId, NotificationType.CancelRequested, "İptal talebi", $"{requester} “{listing.Title}” işinin iptalini istiyor: {reason}. Onayla ya da reddet.", listing.Id, offerId);

    public static Notification CancelApproved(Guid userId, Listing listing, Guid offerId) => New(
        userId, NotificationType.CancelApproved, "İptal onaylandı", $"“{listing.Title}” işi karşılıklı olarak iptal edildi.", listing.Id, offerId);

    public static Notification CancelRejected(Guid userId, Listing listing, Guid offerId) => New(
        userId, NotificationType.CancelRejected, "İptal reddedildi", $"“{listing.Title}” işi için iptal talebin reddedildi; iş devam ediyor.", listing.Id, offerId);

    private static Notification New(Guid userId, NotificationType type, string title, string body, Guid listingId, Guid offerId) =>
        new() { UserId = userId, Type = type, Title = title, Body = body, ListingId = listingId, OfferId = offerId };
}
