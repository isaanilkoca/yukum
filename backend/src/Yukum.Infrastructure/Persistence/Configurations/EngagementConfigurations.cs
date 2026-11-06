using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Domain.Listings;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>"FavoriteListings" tablosu: (kullanıcı, ilan) benzersiz; ilan numarasına göre sayım için ayrıca indeks.</summary>
public class FavoriteListingConfiguration : IEntityTypeConfiguration<FavoriteListing>
{
    /// <summary>Tabloyu tanımlar.</summary>
    public void Configure(EntityTypeBuilder<FavoriteListing> builder)
    {
        builder.ToTable("FavoriteListings");
        builder.HasOne<Listing>().WithMany().HasForeignKey(f => f.ListingId).OnDelete(DeleteBehavior.Restrict);
        builder.HasIndex(f => new { f.UserId, f.ListingId }).IsUnique(); // aynı ilan iki kez favorilenemez (veritabanı garantisi)
        builder.HasIndex(f => f.ListingId);                               // ilanın favori sayısı
    }
}

/// <summary>"ListingViews" tablosu: (ilan, kişi, gün) benzersiz = bir kişi bir günde bir kez sayılır.</summary>
public class ListingViewConfiguration : IEntityTypeConfiguration<ListingView>
{
    /// <summary>Tabloyu tanımlar.</summary>
    public void Configure(EntityTypeBuilder<ListingView> builder)
    {
        builder.ToTable("ListingViews");
        builder.HasOne<Listing>().WithMany().HasForeignKey(v => v.ListingId).OnDelete(DeleteBehavior.Restrict);
        builder.HasIndex(v => new { v.ListingId, v.ViewerId, v.Day }).IsUnique(); // sayım kuralını veritabanı da zorlar
    }
}
