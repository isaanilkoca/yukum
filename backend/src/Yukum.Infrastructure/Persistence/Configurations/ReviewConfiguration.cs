using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Domain.Listings;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>"Reviews" tablosu: iş başına tek yorum (benzersiz indeks), puan 1–5 (CHECK kısıtı), Taşımacı'ya göre hızlı liste için indeks.</summary>
public class ReviewConfiguration : IEntityTypeConfiguration<Review>
{
    /// <summary>Tabloyu tanımlar.</summary>
    public void Configure(EntityTypeBuilder<Review> builder)
    {
        builder.ToTable("Reviews", t => t.HasCheckConstraint("CK_Reviews_Rating", "[Rating] BETWEEN 1 AND 5")); // veritabanı da 1–5 dışını reddeder
        builder.Property(r => r.Comment).HasMaxLength(500);

        builder.HasOne<Offer>().WithMany().HasForeignKey(r => r.OfferId).OnDelete(DeleteBehavior.Restrict);
        builder.HasIndex(r => r.OfferId).IsUnique();                       // bir işe tek yorum: çifte gönderim veritabanında da durur
        builder.HasIndex(r => new { r.CarrierId, r.CreatedAt });            // profil: bu Taşımacı'nın en yeni yorumları
    }
}
