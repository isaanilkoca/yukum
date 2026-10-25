using Yukum.Domain.Common;

namespace Yukum.Domain.Accounts;

/// <summary>
/// Oturumu yenilemeye yarayan uzun ömürlü jeton kaydı. Jetonun kendisi asla saklanmaz, yalnız hash'i saklanır
/// (veritabanı sızsa bile jeton kullanılamaz). Her yenilemede yeni jeton verilir, eskisi geçersiz olur (rotasyon);
/// eski jeton tekrar gelirse çalıntı şüphesiyle zincir iptal edilir (rapor 6.3). <c>RowVersion</c>, iki isteğin aynı
/// jetonu aynı anda yenilemesini (yarış durumu) yakalar.
/// </summary>
public class RefreshToken : BaseEntity
{
    /// <summary>Jetonun sahibi olan kullanıcının numarası.</summary>
    public Guid UserId { get; set; }

    /// <summary>Jetonun hash'i (SHA-256, onaltılık). Benzersizdir.</summary>
    public string TokenHash { get; set; } = "";

    /// <summary>Jetonun verildiği cihazın numarası; iptal "bu cihaz" bazında yapılır.</summary>
    public string DeviceId { get; set; } = "";

    /// <summary>Jetonun geçerlilik bitiş zamanı (UTC).</summary>
    public DateTime ExpiresAt { get; set; }

    /// <summary>İptal edildiyse zamanı (UTC); aksi halde boş.</summary>
    public DateTime? RevokedAt { get; set; }

    /// <summary>Yenilemede bu jetonun yerine geçen yeni jetonun numarası (rotasyon zinciri).</summary>
    public Guid? ReplacedByTokenId { get; set; }
}
