namespace Yukum.Domain.Geography;

/// <summary>
/// Türkiye'nin bir ili (81 adet). Sabit referans verisidir: kullanıcı oluşturmaz, silmez, değiştirmez;
/// bu yüzden <c>BaseEntity</c>'den türemez (o sınıfın Id'si GUID'dir, burada Id plaka kodudur).
/// </summary>
public class City
{
    /// <summary>İlin plaka kodu (1–81) ve aynı zamanda kayıt numarası (karar K-013). Veritabanı üretmez, seed'den gelir.</summary>
    public int Id { get; set; }

    /// <summary>İlin adı (örn. "Konya"). Benzersizdir.</summary>
    public string Name { get; set; } = "";

    /// <summary>İl merkezinin enlemi (derece). Harita ve mesafe hesabı için.</summary>
    public double Latitude { get; set; }

    /// <summary>İl merkezinin boylamı (derece).</summary>
    public double Longitude { get; set; }

    /// <summary>Bu ile bağlı ilçeler.</summary>
    public List<District> Districts { get; set; } = [];
}
