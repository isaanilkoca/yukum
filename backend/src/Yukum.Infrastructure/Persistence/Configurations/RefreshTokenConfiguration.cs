using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Domain.Accounts;
using Yukum.Infrastructure.Identity;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>"RefreshTokens" tablosu: jeton hash'i benzersiz, kullanıcı silinince jetonları da silinir.</summary>
public class RefreshTokenConfiguration : IEntityTypeConfiguration<RefreshToken>
{
    /// <summary>Tablo adını, sütun sınırlarını, indeksleri ve kullanıcı ilişkisini tanımlar.</summary>
    public void Configure(EntityTypeBuilder<RefreshToken> builder)
    {
        builder.ToTable("RefreshTokens");

        // SHA-256 hash'i onaltılık metin olarak 64 karakterdir.
        builder.Property(t => t.TokenHash).IsRequired().HasMaxLength(64);
        builder.Property(t => t.DeviceId).IsRequired().HasMaxLength(100);

        // Hash benzersiz ve hızlı aranır (yenileme isteğinde jeton hash'iyle bulunur).
        builder.HasIndex(t => t.TokenHash).IsUnique();
        // Bir kullanıcının jetonlarını (çıkışta hepsini iptal için) hızlı bulmak için.
        builder.HasIndex(t => t.UserId);

        // Kullanıcı silinince jetonları da silinir (Cascade).
        builder.HasOne<AppUser>().WithMany().HasForeignKey(t => t.UserId).OnDelete(DeleteBehavior.Cascade);
    }
}
