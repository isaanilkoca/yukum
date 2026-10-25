namespace Yukum.Domain.Accounts;

/// <summary>
/// Kullanıcının türü. Kayıt sırasında endpoint belirler, istemciden asla "tür" alanı gelmez (rapor 6.1).
/// Veritabanında sayı olarak saklanır; yeni değer eklenebilir, mevcut sayılar değişmez.
/// </summary>
public enum UserType
{
    /// <summary>Yük Veren: ilan açar, gelen teklifleri kabul/ret eder.</summary>
    Shipper = 1,

    /// <summary>Taşımacı: ilanlara fiyat teklifi verir.</summary>
    Carrier = 2,

    /// <summary>Yönetici: yalnız seed/elle oluşturulur, herkese açık kayıtla olunamaz.</summary>
    Admin = 3
}
