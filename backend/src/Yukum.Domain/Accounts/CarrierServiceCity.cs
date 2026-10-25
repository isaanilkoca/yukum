namespace Yukum.Domain.Accounts;

/// <summary>
/// Taşımacının çalıştığı bir il (çalışma bölgesi). İl numaralarını tek bir metin sütununda tutmak yerine
/// ayrı satırlarda tutarız: veritabanı geçersiz il numarasını reddeder ve "şu ilde çalışanlar" sorgusu kolaylaşır (karar K-016).
/// </summary>
public class CarrierServiceCity
{
    /// <summary>Taşımacının kullanıcı numarası.</summary>
    public Guid CarrierId { get; set; }

    /// <summary>Çalıştığı ilin plaka kodu (<c>Cities.Id</c>).</summary>
    public int CityId { get; set; }
}
