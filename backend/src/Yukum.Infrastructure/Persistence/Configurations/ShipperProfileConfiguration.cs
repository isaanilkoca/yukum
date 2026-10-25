using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Domain.Accounts;
using Yukum.Domain.Geography;
using Yukum.Infrastructure.Identity;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>"ShipperProfiles" tablosu: kullanıcıyla bire bir, kullanıcı silinince birlikte silinir; il mutlaka var olmalı.</summary>
public class ShipperProfileConfiguration : IEntityTypeConfiguration<ShipperProfile>
{
    /// <summary>Anahtarı, sütun sınırlarını ve ilişkileri tanımlar.</summary>
    public void Configure(EntityTypeBuilder<ShipperProfile> builder)
    {
        builder.ToTable("ShipperProfiles");
        // Anahtar kullanıcının numarasıdır: kullanıcı başına tek profil (bire bir ilişki).
        builder.HasKey(p => p.UserId);

        builder.Property(p => p.CompanyName).HasMaxLength(200);
        builder.Property(p => p.TaxNumber).HasMaxLength(20);
        builder.Property(p => p.TaxOffice).HasMaxLength(100);
        builder.Property(p => p.About).HasMaxLength(1000);

        // Kullanıcı silinirse profili de silinir (Cascade). Domain'de AppUser'a referans yok (Domain pakete bağlı kalsın), ilişki burada kurulur.
        builder.HasOne<AppUser>().WithOne().HasForeignKey<ShipperProfile>(p => p.UserId).OnDelete(DeleteBehavior.Cascade);
        // İl numarası mutlaka var olmalı (yabancı anahtar); il silinemez (Restrict).
        builder.HasOne<City>().WithMany().HasForeignKey(p => p.CityId).OnDelete(DeleteBehavior.Restrict);
    }
}
