using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Domain.Geography;
using Yukum.Infrastructure.Persistence.Seed;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>"Cities" tablosunun kuralları: kimlik plaka kodudur, ad benzersizdir, 81 il başlangıçta yüklenir.</summary>
public class CityConfiguration : IEntityTypeConfiguration<City>
{
    /// <summary>Tablonun sütun kurallarını, indeksini ve başlangıç verisini tanımlar.</summary>
    public void Configure(EntityTypeBuilder<City> builder)
    {
        // Tablo adı.
        builder.ToTable("Cities");

        // Birincil anahtar (PK): her satırı tek başına tanıyan sütun.
        builder.HasKey(c => c.Id);
        // Id'yi veritabanı üretmez: plaka kodu seed'den gelir (karar K-013).
        builder.Property(c => c.Id).ValueGeneratedNever();

        // NOT NULL ve en çok 50 karakter (SQL: nvarchar(50)).
        builder.Property(c => c.Name).IsRequired().HasMaxLength(50);
        // Benzersiz indeks: aynı adlı iki il olamaz; veritabanı kendisi reddeder.
        builder.HasIndex(c => c.Name).IsUnique();

        // Başlangıç verisi: migration'a INSERT olarak yazılır (81 satır).
        builder.HasData(GeographySeed.Cities);
    }
}
