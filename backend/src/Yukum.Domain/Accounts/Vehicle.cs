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
    public int CapacityKg { get; set; }

    /// <summary>Hacim kapasitesi, metreküp (opsiyonel).</summary>
    public decimal? CapacityVolume { get; set; }
}
