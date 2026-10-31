using Yukum.Domain.Common;

namespace Yukum.Domain.Listings;

/// <summary>Taşımacının bir ilana verdiği fiyat teklifi. Bir taşımacının bir ilanda tek teklifi olur.</summary>
public class Offer : BaseEntity
{
    /// <summary>Teklifin verildiği ilan.</summary>
    public Guid ListingId { get; set; }

    /// <summary>Teklifi veren Taşımacı'nın kullanıcı numarası (jetondan alınır, istemci göndermez).</summary>
    public Guid CarrierId { get; set; }

    /// <summary>Teklif edilen tutar, TL.</summary>
    public decimal Amount { get; set; }

    /// <summary>Taşımacının notu (opsiyonel).</summary>
    public string? Note { get; set; }

    /// <summary>Teklif durumu.</summary>
    public OfferStatus Status { get; set; } = OfferStatus.Pending;
}
