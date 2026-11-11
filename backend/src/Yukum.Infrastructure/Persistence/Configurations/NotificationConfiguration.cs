using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Domain.Notifications;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>"Notifications" tablosu. Okunmamış sayısı (UserId + ReadAt) ve liste (UserId + CreatedAt) için iki indeks.</summary>
public class NotificationConfiguration : IEntityTypeConfiguration<Notification>
{
    /// <summary>Tabloyu tanımlar.</summary>
    public void Configure(EntityTypeBuilder<Notification> builder)
    {
        builder.ToTable("Notifications");
        builder.Property(n => n.Title).HasMaxLength(100).IsRequired();
        builder.Property(n => n.Body).HasMaxLength(400).IsRequired();
        builder.HasIndex(n => new { n.UserId, n.ReadAt });     // zil rozeti: bu kullanıcının okunmamışları
        builder.HasIndex(n => new { n.UserId, n.CreatedAt });  // liste: bu kullanıcının en yenileri
        // Bilerek yabancı anahtar yok: kullanıcı satırı anonimleşir ama silinmez, bildirimler ise hesap silinirken kendisi silinir.
    }
}
