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
        // Identity'nin 'AspNetUsers' adı yerine sade 'Users'.
        builder.ToTable("Users");

        // Ad zorunlu, en çok 150 karakter.
        builder.Property(u => u.FullName).IsRequired().HasMaxLength(150);
        builder.Property(u => u.AvatarUrl).HasMaxLength(500);

        // E-posta ROL BAŞINA benzersiz (K-022): aynı e-posta bir kez Yük Veren, bir kez Taşımacı olarak kayıt olabilir; aynı role ikinci hesap olamaz.
        // Büyük/küçük harf fark etmez (Identity normalleştirilmiş halini saklar). Identity'nin hazır "EmailIndex" indeksi artık yalnız arama içindir.
        builder.HasIndex(u => new { u.NormalizedEmail, u.UserType }).IsUnique();

        // Telefon da ROL BAŞINA benzersiz. SQL Server benzersiz indeksi boş (NULL) telefonu filtreler (silinmiş hesaplar telefonsuzdur).
        builder.HasIndex(u => new { u.PhoneNumber, u.UserType }).IsUnique();
    }
}
