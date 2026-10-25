namespace Yukum.Domain.Accounts;

/// <summary>
/// Yük Veren'e ait ek bilgiler. Kullanıcı kaydıyla (Users) bire bir bağlıdır; anahtarı kullanıcının numarasıdır.
/// </summary>
public class ShipperProfile
{
    /// <summary>Bağlı olduğu kullanıcının numarası (aynı zamanda bu satırın anahtarı).</summary>
    public Guid UserId { get; set; }

    /// <summary>Firma adı. Bireysel kullanıcıda boş olabilir.</summary>
    public string? CompanyName { get; set; }

    /// <summary>Vergi numarası (opsiyonel, kişisel veri: sınırlı erişim).</summary>
    public string? TaxNumber { get; set; }

    /// <summary>Vergi dairesi (opsiyonel).</summary>
    public string? TaxOffice { get; set; }

    /// <summary>Kısa tanıtım yazısı.</summary>
    public string? About { get; set; }

    /// <summary>Bulunduğu ilin plaka kodu (<c>Cities.Id</c>).</summary>
    public int CityId { get; set; }
}
