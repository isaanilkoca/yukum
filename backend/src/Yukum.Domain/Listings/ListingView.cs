using Yukum.Domain.Common;

namespace Yukum.Domain.Listings;

/// <summary>Bir Taşımacı'nın bir ilanı bir günde görüntülemesi. (İlan, Taşımacı, gün) üçlüsü benzersizdir: aynı kişi aynı gün kaç kez açsa tek sayılır.</summary>
public class ListingView : BaseEntity
{
    /// <summary>Görüntülenen ilan.</summary>
    public Guid ListingId { get; set; }

    /// <summary>İlana bakan Taşımacı.</summary>
    public Guid ViewerId { get; set; }

    /// <summary>Bakılan gün (UTC).</summary>
    public DateOnly Day { get; set; }
}
