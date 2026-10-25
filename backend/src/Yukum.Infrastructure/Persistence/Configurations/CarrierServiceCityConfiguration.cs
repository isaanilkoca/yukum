using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Domain.Accounts;
using Yukum.Domain.Geography;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>"CarrierServiceCities" tablosu: (taşımacı, il) çifti benzersizdir; il mutlaka var olmalı.</summary>
public class CarrierServiceCityConfiguration : IEntityTypeConfiguration<CarrierServiceCity>
{
    /// <summary>Birleşik anahtarı ve il ilişkisini tanımlar.</summary>
    public void Configure(EntityTypeBuilder<CarrierServiceCity> builder)
    {
        builder.ToTable("CarrierServiceCities");
        builder.HasKey(c => new { c.CarrierId, c.CityId });

        builder.HasOne<City>().WithMany().HasForeignKey(c => c.CityId).OnDelete(DeleteBehavior.Restrict);
    }
}
