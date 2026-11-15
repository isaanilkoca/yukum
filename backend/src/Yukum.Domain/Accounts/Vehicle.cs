using Yukum.Domain.Common;

namespace Yukum.Domain.Accounts;

/// <summary>Taşımacının bir aracı. Bir taşımacının birden çok aracı olabilir.</summary>
public class Vehicle : BaseEntity
{
    /// <summary>Sahibi olan taşımacının kullanıcı numarası.</summary>
    public Guid CarrierId { get; set; }

    /// <summary>Araç tipi.</summary>
    public VehicleType Type { get; set; }

    /// <summary>Plaka (opsiyonel; kayıtta zorunlu değildir).</summary>
    public string? PlateNumber { get; set; }

    /// <summary>Taşıma kapasitesi, kilogram.</summary>
    public int? CapacityKg { get; set; } // 15 Kasım: isteğe bağlı (yönetici: araç "plakası ve türüne göre" kaydedilir)

    /// <summary>Hacim kapasitesi, metreküp (opsiyonel).</summary>
    public decimal? CapacityVolume { get; set; }

    // ─── 15 Kasım (kullanıcı: "aracın yaşı, markası, modeli zorunlu; ilan veren görebilsin, daha kaliteli araç isteyebilir") ───
    // DB'de boş bırakılabilir (eski kayıtlar), API'de ZORUNLU: Araçlarım'dan kaydederken (SaveVehicleHandler) ve teklif verirken (CreateOfferHandler) aranır.

    /// <summary>Marka (ör. Mercedes-Benz).</summary>
    public string? Brand { get; set; }

    /// <summary>Model (ör. Actros 1845).</summary>
    public string? Model { get; set; }

    /// <summary>Model yılı (ör. 2019) → Yük Veren aracın yaşını buradan görür.</summary>
    public int? Year { get; set; }

    /// <summary>Marka + model + yıl dolu mu? (teklif şartı)</summary>
    public bool HasDetails => !string.IsNullOrWhiteSpace(Brand) && !string.IsNullOrWhiteSpace(Model) && Year is not null;
}
