using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Domain.Geography;
using Yukum.Domain.Listings;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>"Listings" tablosu: sütun sınırları, il/ilçe bağları ve ilan sahibi indeksi.</summary>
public class ListingConfiguration : IEntityTypeConfiguration<Listing>
{
    /// <summary>Tabloyu tanımlar.</summary>
    public void Configure(EntityTypeBuilder<Listing> builder)
    {
        builder.ToTable("Listings");

        builder.Property(l => l.Title).HasMaxLength(150).IsRequired();
        builder.Property(l => l.Description).HasMaxLength(2000);
        builder.Property(l => l.Budget).HasPrecision(12, 2);

        // İl/ilçe numaraları gerçek il/ilçeye bağlı; silinmeye karşı korumalı (Restrict).
        builder.HasOne<City>().WithMany().HasForeignKey(l => l.FromCityId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<City>().WithMany().HasForeignKey(l => l.ToCityId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<District>().WithMany().HasForeignKey(l => l.FromDistrictId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<District>().WithMany().HasForeignKey(l => l.ToDistrictId).OnDelete(DeleteBehavior.Restrict);

        // "İlanlarım" sorgusu için.
        builder.HasIndex(l => l.ShipperId);
    }
}
