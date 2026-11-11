using Yukum.Domain.Common;

namespace Yukum.Domain.Notifications;

/// <summary>
/// Bir kullanıcıya gösterilecek uygulama içi bildirim. Olayın kendisiyle AYNI işlemde (transaction) yazılır: teklif kaydedildi ama bildirim yazılmadı gibi
/// tutarsızlık olmaz. Bu tablo aynı zamanda ileride push için "gönderilecekler kutusu"dur (outbox): PushedAt boş olanlar henüz telefona gönderilmemiştir.
/// </summary>
public class Notification : BaseEntity
{
    /// <summary>Bildirimi alacak kullanıcı.</summary>
    public Guid UserId { get; set; }

    /// <summary>Bildirim türü.</summary>
    public NotificationType Type { get; set; }

    /// <summary>Kısa başlık (örn. "Yeni teklif").</summary>
    public string Title { get; set; } = "";

    /// <summary>Açıklama metni. Karşı tarafın kişisel bilgisi (ad, telefon) içermez.</summary>
    public string Body { get; set; } = "";

    /// <summary>İlgili ilan (varsa): istemci dokununca ilgili ekrana gitsin.</summary>
    public Guid? ListingId { get; set; }

    /// <summary>İlgili teklif (varsa).</summary>
    public Guid? OfferId { get; set; }

    /// <summary>Kullanıcının okuduğu an (UTC). Boşsa okunmamış.</summary>
    public DateTime? ReadAt { get; set; }

    /// <summary>
    /// Telefona push olarak gönderildiği an (UTC). Şimdilik hep boş: push (APNs) için ücretli Apple hesabı gerekir, henüz yok.
    /// Push eklenince arka plan işçisi PushedAt boş satırları gönderip bunu doldurur; tabloda başka değişiklik gerekmez.
    /// </summary>
    public DateTime? PushedAt { get; set; }
}
