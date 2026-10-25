using Microsoft.AspNetCore.Identity;
using Yukum.Domain.Accounts;

namespace Yukum.Infrastructure.Persistence.Seed;

/// <summary>
/// Üç rolün (Admin, Shipper, Carrier) başlangıç kayıtları. Numaraları sabittir: her ortamda (geliştirme, test, canlı)
/// aynı rol aynı numarayı taşır, migration tekrar üretildiğinde değişmez (karar K-016).
/// </summary>
public static class RoleSeed
{
    /// <summary>Admin rolünün sabit numarası.</summary>
    public static readonly Guid AdminId = Guid.Parse("00000000-0000-4000-8000-0000000000a1");

    /// <summary>Shipper (Yük Veren) rolünün sabit numarası.</summary>
    public static readonly Guid ShipperId = Guid.Parse("00000000-0000-4000-8000-0000000000a2");

    /// <summary>Carrier (Taşımacı) rolünün sabit numarası.</summary>
    public static readonly Guid CarrierId = Guid.Parse("00000000-0000-4000-8000-0000000000a3");

    /// <summary>Seed olarak eklenecek rol kayıtları.</summary>
    public static IReadOnlyList<IdentityRole<Guid>> Roles { get; } =
    [
        // NormalizedName: Identity'nin aramada kullandığı BÜYÜK harfli ad. ConcurrencyStamp sabit (migration yeniden üretilince değişmesin).
        new() { Id = AdminId, Name = RoleNames.Admin, NormalizedName = RoleNames.Admin.ToUpperInvariant(), ConcurrencyStamp = "role-admin-v1" },
        new() { Id = ShipperId, Name = RoleNames.Shipper, NormalizedName = RoleNames.Shipper.ToUpperInvariant(), ConcurrencyStamp = "role-shipper-v1" },
        new() { Id = CarrierId, Name = RoleNames.Carrier, NormalizedName = RoleNames.Carrier.ToUpperInvariant(), ConcurrencyStamp = "role-carrier-v1" }
    ];
}
