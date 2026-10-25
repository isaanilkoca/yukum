using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Domain.Accounts;
using Yukum.Domain.Geography;
using Yukum.Infrastructure.Identity;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>
/// "CarrierProfiles" tablosu: kullanıcıyla bire bir; araçları ve çalışma bölgeleri profille birlikte silinir;
/// merkez il mutlaka var olmalı.
/// </summary>
public class CarrierProfileConfiguration : IEntityTypeConfiguration<CarrierProfile>
{
    /// <summary>Anahtarı, sütun sınırlarını ve ilişkileri tanımlar.</summary>
    public void Configure(EntityTypeBuilder<CarrierProfile> builder)
    {
        builder.ToTable("CarrierProfiles");
        builder.HasKey(p => p.UserId);

        builder.Property(p => p.About).HasMaxLength(1000);
        builder.Property(p => p.AverageRating).HasPrecision(3, 2);

        builder.HasOne<AppUser>().WithOne().HasForeignKey<CarrierProfile>(p => p.UserId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<City>().WithMany().HasForeignKey(p => p.HomeCityId).OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(p => p.Vehicles).WithOne().HasForeignKey(v => v.CarrierId).OnDelete(DeleteBehavior.Cascade);
        builder.HasMany(p => p.ServiceCities).WithOne().HasForeignKey(c => c.CarrierId).OnDelete(DeleteBehavior.Cascade);
    }
}
