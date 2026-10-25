using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Domain.Geography;
using Yukum.Infrastructure.Persistence.Seed;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>
/// "Districts" tablosunun kuralları: kimlik sıralı sayıdır, her ilçe mutlaka bir ile bağlıdır,
/// aynı il içinde ilçe adı tekrar edemez, 973 ilçe başlangıçta yüklenir.
/// </summary>
public class DistrictConfiguration : IEntityTypeConfiguration<District>
{
    /// <summary>Tablonun sütun kurallarını, ilişkisini, indeksini ve başlangıç verisini tanımlar.</summary>
    public void Configure(EntityTypeBuilder<District> builder)
    {
        builder.ToTable("Districts");

        builder.HasKey(d => d.Id);
        // Id'yi veritabanı üretmez: sıra numarası seed'den gelir (karar K-013).
        builder.Property(d => d.Id).ValueGeneratedNever();

        builder.Property(d => d.Name).IsRequired().HasMaxLength(100);

        // Her ilçe bir ile bağlıdır; ili silmek ilçelerini sessizce silmesin diye Restrict (engelle).
        builder.HasOne(d => d.City)
            .WithMany(c => c.Districts)
            .HasForeignKey(d => d.CityId)
            .OnDelete(DeleteBehavior.Restrict);

        // Aynı ilde aynı adlı iki ilçe olamaz; farklı illerde "Merkez" gibi adlar tekrar edebilir.
        builder.HasIndex(d => new { d.CityId, d.Name }).IsUnique();

        builder.HasData(GeographySeed.Districts);
    }
}
