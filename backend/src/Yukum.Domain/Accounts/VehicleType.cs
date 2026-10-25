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

    /// <summary>Listede olmayan diğer araçlar.</summary>
    Other = 99
}
