using Yukum.Domain.Common;

namespace Yukum.Domain.Listings;

/// <summary>Bir Taşımacı'nın bir ilanı favorilemesi. (Kullanıcı, ilan) çifti benzersizdir: aynı ilan iki kez favorilenemez.</summary>
public class FavoriteListing : BaseEntity
{
    /// <summary>Favoriyi ekleyen Taşımacı.</summary>
    public Guid UserId { get; set; }

    /// <summary>Favorilenen ilan.</summary>
    public Guid ListingId { get; set; }
}
