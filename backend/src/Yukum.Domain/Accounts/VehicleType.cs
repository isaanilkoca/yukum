namespace Yukum.Domain.Accounts;

/// <summary>
/// Araç tipi (karar K-016). Veritabanında sayı olarak saklanır; yeni tip eklenebilir, mevcut sayılar değişmez.
/// "Diğer", listede olmayan araçlar içindir.
/// </summary>
public enum VehicleType
{
    /// <summary>Tır (çekici + dorse): büyük yük, uzun yol.</summary>
    Truck = 1,

    /// <summary>Kamyon: orta ve büyük yük.</summary>
    Lorry = 2,

    /// <summary>Kamyonet: küçük yük, kısa mesafe.</summary>
    Pickup = 3,

    /// <summary>Frigorifik (soğutmalı) araç: gıda, ilaç gibi soğuk zincir.</summary>
    Refrigerated = 4,

    /// <summary>Otomobil / şahsi araç (15 Kasım, kullanıcı: "küçük paketi şahsi arabasıyla da götürebilir").</summary>
    Car = 5,

    /// <summary>Listede olmayan diğer araçlar.</summary>
    Other = 99,

    /// <summary>
    /// "Farketmez" (15 Kasım, kullanıcı: "Yük Veren illa birini seçmek zorunda olmasın"). YALNIZ İLANDA kullanılır:
    /// her araç türündeki Taşımacı bu ilanı görür (araç filtresi Any ilanı dışlamaz). Araç kaydında GEÇERSİZ (VehicleHandlers reddeder).
    /// NEDEN 0 değil 100: JSON'da alan unutulursa enum 0 olur → sessizce "farketmez" sayılmasın; 0 tanımsız kalır, doğrulama yakalar.
    /// </summary>
    Any = 100
}
