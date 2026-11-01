using Yukum.Domain.Common;

namespace Yukum.Domain.Listings;

/// <summary>Bir teklifin sohbetindeki tek mesaj. Sohbet = aynı OfferId'ye bağlı mesajlar (ilan sahibi ↔ teklifi veren taşımacı).</summary>
public class Message : BaseEntity
{
    /// <summary>Mesajın ait olduğu teklif (sohbetin kimliği).</summary>
    public Guid OfferId { get; set; }

    /// <summary>Mesajı yazan kullanıcı (jetondan alınır, istemci göndermez).</summary>
    public Guid SenderId { get; set; }

    /// <summary>Mesaj metni.</summary>
    public string Text { get; set; } = "";
}
