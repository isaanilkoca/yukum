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

        // Sütun adı raporla uyumlu 'VehicleType'; enum SAYI olarak saklanır (Truck=1, Lorry=2...).
        builder.Property(v => v.Type).HasColumnName("VehicleType");
        // 15 Kasım: marka/model (yıl int) | HasDetails hesaplanan özellik, sütun değil
        builder.Property(v => v.Brand).HasMaxLength(50);
        builder.Property(v => v.Model).HasMaxLength(50);
        builder.Ignore(v => v.HasDetails);
        builder.Property(v => v.PlateNumber).HasMaxLength(20);
        // decimal(9,2): metreküp için.
        builder.Property(v => v.CapacityVolume).HasPrecision(9, 2);

        // Bir taşımacının araçlarını hızlı bulmak için indeks.
        builder.HasIndex(v => v.CarrierId);
    }
}
