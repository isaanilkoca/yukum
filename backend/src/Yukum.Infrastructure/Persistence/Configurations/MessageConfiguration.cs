using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Domain.Listings;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>"Messages" tablosu: metin sınırı, teklife bağ ve sohbet sırası için indeks.</summary>
public class MessageConfiguration : IEntityTypeConfiguration<Message>
{
    /// <summary>Tabloyu tanımlar.</summary>
    public void Configure(EntityTypeBuilder<Message> builder)
    {
        builder.ToTable("Messages");
        builder.Property(m => m.Text).HasMaxLength(1000).IsRequired();
        builder.HasOne<Offer>().WithMany().HasForeignKey(m => m.OfferId).OnDelete(DeleteBehavior.Restrict);
        // Bir sohbetin mesajlarını zaman sırasıyla getirmek için.
        builder.HasIndex(m => new { m.OfferId, m.CreatedAt });
    }
}
