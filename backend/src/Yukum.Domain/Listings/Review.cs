using Yukum.Domain.Common;

namespace Yukum.Domain.Listings;

/// <summary>Yük Veren'in tamamlanmış bir iş için Taşımacı'ya verdiği puan ve yorum. Her iş (teklif) için en çok bir tane.</summary>
public class Review : BaseEntity
{
    /// <summary>Puanlanan iş (kabul edilip tamamlanmış teklif). Benzersiz: bir işe tek yorum.</summary>
    public Guid OfferId { get; set; }

    /// <summary>İşin ilanı (profilde rota göstermek için).</summary>
    public Guid ListingId { get; set; }

    /// <summary>Puanlanan Taşımacı.</summary>
    public Guid CarrierId { get; set; }

    /// <summary>Puanı veren Yük Veren (işin ilan sahibi).</summary>
    public Guid ShipperId { get; set; }

    /// <summary>1–5 arası puan.</summary>
    public int Rating { get; set; }

    /// <summary>Kısa yorum (isteğe bağlı).</summary>
    public string? Comment { get; set; }
}
