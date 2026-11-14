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

    /// <summary>Yük Veren'in karar verdiği an (UTC); bekleyen teklifte boştur.</summary>
    public DateTime? DecidedAt { get; set; }

    /// <summary>İşin aşaması (yük alındı, yolda, teslim edildi). Yalnız Kabul edilmiş teklifte anlamlıdır.</summary>
    public JobStage Stage { get; set; } = JobStage.NotStarted;

    /// <summary>Taşımacı karar bildirimini gördü mü? Karar verilince false olur ("Yeni" rozeti), taşımacı geçmişi açınca true olur.</summary>
    public bool CarrierSeen { get; set; }

    /// <summary>Taşımacı bu teklifi geçmişinden sildi mi? (kayıt durur, yalnız onun listesinden gizlenir)</summary>
    public bool HiddenByCarrier { get; set; }

    /// <summary>Yük Veren bu teklifi geçmişinden sildi mi? (kayıt durur, yalnız onun listesinden gizlenir)</summary>
    public bool HiddenByShipper { get; set; }

    // ─── KARŞILIKLI İPTAL (15 Kasım) ───
    // Kabul edilmiş, teslim edilmemiş işte bir taraf iptal ister; karşı taraf onaylarsa iş iptal olur. Tek taraf işi bozamaz.
    // Talep yokken hepsi boş. Onay/ret/geri çekmede talep alanları temizlenir; onayda MutuallyCancelled işaretlenir (geçmişte "Karşılıklı iptal").

    /// <summary>İptali isteyen kullanıcı (Yük Veren ya da Taşımacı). null = açık talep yok.</summary>
    public Guid? CancelRequestedBy { get; set; }

    /// <summary>İptal nedeni (kısa: "Araç arızası", "Yük hazır değil"...).</summary>
    public string? CancelReason { get; set; }

    /// <summary>İsteğe bağlı açıklama.</summary>
    public string? CancelNote { get; set; }

    /// <summary>Talebin zamanı.</summary>
    public DateTime? CancelRequestedAt { get; set; }

    /// <summary>Yük Veren'in seçimi (talebi Yük Veren açtıysa): onaylanınca ilan yeniden yayınlansın mı? Taşımacı açtıysa onaylarken seçer.</summary>
    public bool? CancelReopenListing { get; set; }

    /// <summary>İş karşılıklı anlaşmayla iptal edildi (Status = Cancelled ile birlikte).</summary>
    public bool MutuallyCancelled { get; set; }
}
