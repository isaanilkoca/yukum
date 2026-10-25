namespace Yukum.Domain.Accounts;

/// <summary>
/// Sistemdeki üç rolün adı. Yetki kontrolü (<c>[Authorize(Roles = ...)]</c>, policy'ler) hep bu sabitleri kullanır;
/// elle yazılan metin yazım hatasına açıktır.
/// </summary>
public static class RoleNames
{
    /// <summary>Yönetici rolü.</summary>
    public const string Admin = "Admin";

    /// <summary>Yük Veren rolü.</summary>
    public const string Shipper = "Shipper";

    /// <summary>Taşımacı rolü.</summary>
    public const string Carrier = "Carrier";
}
