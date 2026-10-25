namespace Yukum.Domain.Geography;

/// <summary>
/// Bir ilin ilçesi (toplam 973). <c>City</c> gibi sabit referans verisidir, <c>BaseEntity</c>'den türemez.
/// </summary>
public class District
{
    /// <summary>
    /// Sıralı kayıt numarası (1–973): önce il plaka sırası, sonra ilçenin Türkçe alfabetik sırası (karar K-013).
    /// Seed dondurulmuştur; sonradan eklenen ilçe sıradaki numarayı alır, mevcut numaralar değişmez.
    /// </summary>
    public int Id { get; set; }

    /// <summary>Bağlı olduğu ilin kayıt numarası (plaka kodu).</summary>
    public int CityId { get; set; }

    /// <summary>Bağlı olduğu il.</summary>
    public City City { get; set; } = null!;

    /// <summary>İlçenin adı (örn. "Meram"). Aynı il içinde benzersizdir; farklı illerde aynı ad olabilir ("Merkez").</summary>
    public string Name { get; set; } = "";

    /// <summary>İlçe merkezinin enlemi (derece).</summary>
    public double Latitude { get; set; }

    /// <summary>İlçe merkezinin boylamı (derece).</summary>
    public double Longitude { get; set; }
}
