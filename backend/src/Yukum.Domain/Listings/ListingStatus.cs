namespace Yukum.Domain.Listings;

/// <summary>İlanın durumu. Veritabanında sayı olarak saklanır.</summary>
public enum ListingStatus
{
    /// <summary>Açık: taşımacılar görebilir (şimdilik tek durum; kapanma/iptal teklif aşamasında eklenecek).</summary>
    Open = 1
}
