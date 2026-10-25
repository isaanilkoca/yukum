using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Domain.Accounts;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>"Vehicles" tablosu: araç tipi sayı olarak saklanır; sütun adı raporla uyumlu olarak "VehicleType"tır.</summary>
public class VehicleConfiguration : IEntityTypeConfiguration<Vehicle>
{
    /// <summary>Tablo adını, sütun sınırlarını ve taşımacı indeksini tanımlar.</summary>
    public void Configure(EntityTypeBuilder<Vehicle> builder)
    {
        builder.ToTable("Vehicles");

        builder.Property(v => v.Type).HasColumnName("VehicleType");
        builder.Property(v => v.PlateNumber).HasMaxLength(20);
        builder.Property(v => v.CapacityVolume).HasPrecision(9, 2);

        builder.HasIndex(v => v.CarrierId);
    }
}
