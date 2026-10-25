using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Infrastructure.Identity;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>"Users" tablosunun kuralları: ad zorunlu, e-posta ve telefon benzersiz (veritabanı düzeyinde).</summary>
public class AppUserConfiguration : IEntityTypeConfiguration<AppUser>
{
    /// <summary>Tablo adını, sütun sınırlarını ve benzersizlik indekslerini tanımlar.</summary>
    public void Configure(EntityTypeBuilder<AppUser> builder)
    {
        builder.ToTable("Users");

        builder.Property(u => u.FullName).IsRequired().HasMaxLength(150);
        builder.Property(u => u.AvatarUrl).HasMaxLength(500);

        // Aynı e-posta iki kez kayıt olamaz (büyük/küçük harf fark etmez: Identity normalleştirilmiş halini saklar).
        // Identity'nin hazır "EmailIndex" indeksi (adı değişmez) benzersiz yapılır; ikinci bir indeks açılmaz.
        builder.HasIndex(u => u.NormalizedEmail).IsUnique();

        // Aynı telefon iki kez kullanılamaz. SQL Server benzersiz indeksi boş (NULL) değerleri filtreler,
        // yani telefonsuz birden çok kullanıcı olabilir.
        builder.HasIndex(u => u.PhoneNumber).IsUnique();
    }
}
