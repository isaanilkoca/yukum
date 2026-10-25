namespace Yukum.Domain.Accounts;

/// <summary>
/// Taşımacı'ya ait ek bilgiler. Kullanıcı kaydıyla (Users) bire bir bağlıdır; anahtarı kullanıcının numarasıdır.
/// </summary>
public class CarrierProfile
{
    /// <summary>Bağlı olduğu kullanıcının numarası (aynı zamanda bu satırın anahtarı).</summary>
    public Guid UserId { get; set; }

    /// <summary>Kısa tanıtım yazısı.</summary>
    public string? About { get; set; }

    /// <summary>Merkez aldığı ilin plaka kodu (<c>Cities.Id</c>).</summary>
    public int HomeCityId { get; set; }

    /// <summary>Puan ortalaması (0–5). Hız için burada saklanır; yorum eklenince aynı işlemde güncellenir (ileriki aşama).</summary>
    public decimal AverageRating { get; set; }

    /// <summary>Kaç kişi puan verdi.</summary>
    public int RatingCount { get; set; }

    /// <summary>Tamamlanan iş sayısı.</summary>
    public int CompletedJobCount { get; set; }

    /// <summary>Şu an yeni iş alabilir mi? Varsayılan evet.</summary>
    public bool IsAvailable { get; set; } = true;

    /// <summary>Taşımacının araçları.</summary>
    public List<Vehicle> Vehicles { get; set; } = [];

    /// <summary>Çalıştığı iller (çalışma bölgeleri).</summary>
    public List<CarrierServiceCity> ServiceCities { get; set; } = [];
}
