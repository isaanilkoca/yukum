namespace Yukum.Domain.Listings;

/// <summary>İlanın durumu. Veritabanında sayı olarak saklanır.</summary>
public enum ListingStatus
{
    /// <summary>Açık: taşımacılar görebilir (şimdilik tek durum; kapanma/iptal teklif aşamasında eklenecek).</summary>
    Open = 1,

    /// <summary>Atandı: bir teklif kabul edildi, ilan açık listeden düştü.</summary>
    Assigned = 2,

    /// <summary>Tamamlandı: atanan iş bitti.</summary>
    Completed = 3,

    /// <summary>Yayından kaldırıldı: ilan sahibi iptal etti. Hiçbir listede görünmez.</summary>
    Cancelled = 4
}
