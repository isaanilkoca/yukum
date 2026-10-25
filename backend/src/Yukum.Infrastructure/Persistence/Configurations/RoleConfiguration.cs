using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Infrastructure.Persistence.Seed;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>"Roles" tablosu: Admin, Shipper ve Carrier rolleri başlangıçta yüklenir.</summary>
public class RoleConfiguration : IEntityTypeConfiguration<IdentityRole<Guid>>
{
    /// <summary>Tablo adını verir ve üç rolü seed eder.</summary>
    public void Configure(EntityTypeBuilder<IdentityRole<Guid>> builder)
    {
        builder.ToTable("Roles");
        builder.HasData(RoleSeed.Roles);
    }
}
