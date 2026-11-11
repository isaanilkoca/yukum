namespace Yukum.Domain.Notifications;

/// <summary>Bildirimin türü. Sayı olarak saklanır (sırayı değiştirme, yalnız sona ekle). İstemci simge/yönlendirme için kullanır.</summary>
public enum NotificationType
{
    /// <summary>Yük Veren: ilanına teklif geldi (ya da teklif tutarı güncellendi).</summary>
    OfferReceived = 1,

    /// <summary>Taşımacı: teklifi kabul edildi.</summary>
    OfferAccepted = 2,

    /// <summary>Taşımacı: teklifi reddedildi (ya da başka teklif seçildi).</summary>
    OfferRejected = 3,

    /// <summary>Yük Veren: işin aşaması değişti (yük alındı, yolda, teslim edildi).</summary>
    JobStageChanged = 4,

    /// <summary>İş tamamlandı; karşı tarafa haber verilir.</summary>
    JobCompleted = 5,

    /// <summary>Taşımacı: yeni puan/yorum aldı.</summary>
    ReviewReceived = 6,

    /// <summary>Taşımacı: teklif verdiği ilan kaldırıldı.</summary>
    ListingCancelled = 7
}
