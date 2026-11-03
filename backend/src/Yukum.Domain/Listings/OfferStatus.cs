namespace Yukum.Domain.Listings;

/// <summary>Teklifin durumu. Veritabanında sayı olarak saklanır.</summary>
public enum OfferStatus
{
    /// <summary>Beklemede: Yük Veren henüz karar vermedi.</summary>
    Pending = 1,

    /// <summary>Kabul edildi: Yük Veren bu teklifi seçti.</summary>
    Accepted = 2,

    /// <summary>Reddedildi: Yük Veren reddetti ya da başka teklif kabul edildi.</summary>
    Rejected = 3,

    /// <summary>Tamamlandı: iş bitti, anlaşma tamam. Sohbet iki tarafta yazmaya kapanır; taraflar kendi geçmişlerinden silebilir.</summary>
    Completed = 4
}
