using Yukum.Domain.Common;

namespace Yukum.Domain.Notifications;

/// <summary>
/// Bir telefonun push adresi (APNs cihaz jetonu). Apple her uygulama kurulumuna bir jeton verir; sunucu bildirimi bu adrese yollar.
/// Jeton benzersizdir: aynı telefonda başka hesapla giriş yapılırsa satır yeni kullanıcıya geçer (eski kullanıcıya bildirim gitmez).
/// </summary>
public class DeviceToken : BaseEntity
{
    /// <summary>Bu telefonda giriş yapmış kullanıcı.</summary>
    public Guid UserId { get; set; }

    /// <summary>Uygulamanın kendi cihaz kimliği (giriş/yenileme jetonundaki deviceId ile aynı).</summary>
    public string DeviceId { get; set; } = "";

    /// <summary>APNs cihaz jetonu (onaltılık yazı).</summary>
    public string Token { get; set; } = "";

    /// <summary>true: Xcode'dan kurulan geliştirme sürümü (APNs "sandbox" sunucusu). false: TestFlight/App Store (production).</summary>
    public bool Sandbox { get; set; }
}
