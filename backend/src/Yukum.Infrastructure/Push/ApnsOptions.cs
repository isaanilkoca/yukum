namespace Yukum.Infrastructure.Push;

/// <summary>Apple push (APNs) ayarları. appsettings "Apns" bölümü; anahtar yolu ve kimlikler user-secrets / ortam değişkeninden gelir.</summary>
public sealed class ApnsOptions
{
    /// <summary>false ise push kapalıdır: işçi çalışmaz, uygulama içi bildirimler etkilenmez (varsayılan; testlerde de kapalı).</summary>
    public bool Enabled { get; set; }

    /// <summary>Apple'dan indirilen .p8 anahtar dosyasının YOLU. Dosya repoya konmaz.</summary>
    public string KeyPath { get; set; } = "";

    /// <summary>Anahtarın kimliği (Key ID, 10 karakter).</summary>
    public string KeyId { get; set; } = "";

    /// <summary>Geliştirici takım kimliği (Team ID, 10 karakter).</summary>
    public string TeamId { get; set; } = "";

    /// <summary>Uygulamanın Bundle ID'si (APNs "topic").</summary>
    public string BundleId { get; set; } = "";

    /// <summary>İşçi kaç saniyede bir bekleyen bildirimlere bakar.</summary>
    public int PollSeconds { get; set; } = 10;
}
