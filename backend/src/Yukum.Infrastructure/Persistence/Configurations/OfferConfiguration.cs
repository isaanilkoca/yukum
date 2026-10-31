using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Domain.Listings;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>"Offers" tablosu: sütun sınırları, ilana bağ ve "bir taşımacı bir ilana tek teklif" kuralı.</summary>
public class OfferConfiguration : IEntityTypeConfiguration<Offer>
{
    /// <summary>Tabloyu tanımlar.</summary>
    public void Configure(EntityTypeBuilder<Offer> builder)
    {
        builder.ToTable("Offers");

        builder.Property(o => o.Amount).HasPrecision(12, 2);
        builder.Property(o => o.Note).HasMaxLength(500);

        // İlan silinmeye karşı korumalı (Restrict).
        builder.HasOne<Listing>().WithMany().HasForeignKey(o => o.ListingId).OnDelete(DeleteBehavior.Restrict);

        // Aynı taşımacı aynı ilana ikinci teklif satırı açamaz (tekrar teklif = tutarı güncelleme).
        builder.HasIndex(o => new { o.ListingId, o.CarrierId }).IsUnique();
    }
}
