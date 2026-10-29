using Yukum.Domain.Accounts;
using Yukum.Domain.Common;

namespace Yukum.Domain.Listings;

/// <summary>Yük Veren'in açtığı taşıma ilanı. Taşımacılar bu ilana teklif verecek.</summary>
public class Listing : BaseEntity
{
    /// <summary>İlanı açan Yük Veren'in kullanıcı numarası (jetondan alınır, istemci göndermez).</summary>
    public Guid ShipperId { get; set; }

    /// <summary>Başlık, örn. "20 palet tarım ilacı".</summary>
    public string Title { get; set; } = "";

    /// <summary>Açıklama (opsiyonel).</summary>
    public string? Description { get; set; }

    /// <summary>Yükün ağırlığı, kilogram.</summary>
    public int WeightKg { get; set; }

    /// <summary>İstenen araç tipi.</summary>
    public VehicleType VehicleType { get; set; }

    /// <summary>Kalkış ili (plaka kodu).</summary>
    public int FromCityId { get; set; }

    /// <summary>Kalkış ilçesi.</summary>
    public int FromDistrictId { get; set; }

    /// <summary>Varış ili (plaka kodu).</summary>
    public int ToCityId { get; set; }

    /// <summary>Varış ilçesi.</summary>
    public int ToDistrictId { get; set; }

    /// <summary>Yükleme günü (saat yok).</summary>
    public DateOnly PickupDate { get; set; }

    /// <summary>Beklenen fiyat, TL (opsiyonel).</summary>
    public decimal? Budget { get; set; }

    /// <summary>İlan durumu.</summary>
    public ListingStatus Status { get; set; } = ListingStatus.Open;
}
