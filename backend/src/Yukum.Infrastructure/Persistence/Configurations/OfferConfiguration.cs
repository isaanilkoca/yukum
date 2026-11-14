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
        builder.Property(o => o.CancelReason).HasMaxLength(60);   // karşılıklı iptal nedeni (kısa)
        builder.Property(o => o.CancelNote).HasMaxLength(300);

        // İlan silinmeye karşı korumalı (Restrict).
        builder.HasOne<Listing>().WithMany().HasForeignKey(o => o.ListingId).OnDelete(DeleteBehavior.Restrict);

        // Aynı taşımacı aynı ilana ikinci teklif satırı açamaz (tekrar teklif = tutarı güncelleme).
        builder.HasIndex(o => new { o.ListingId, o.CarrierId }).IsUnique();

        // İNDEKS KURALI: bileşik indeks yalnız SOL SÜTUNDAN başlayan aramalara yarar. Yukarıdaki (ListingId, CarrierId) indeksi
        // "ListingId'ye göre" aramaya yarar ama "yalnız CarrierId'ye göre" aramaya yaramaz; bu yüzden aşağıdakiler ayrıca gerekli.
        builder.HasIndex(o => new { o.CarrierId, o.Status });   // Tekliflerim, okunmamış rozet (her Taşımacı ana sayfası açılışında), aktif iş kontrolü
        builder.HasIndex(o => new { o.Status, o.DecidedAt });   // emsal fiyat: son 180 günün Tamamlandı teklifleri
    }
}
