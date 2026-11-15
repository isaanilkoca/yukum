using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Domain.Accounts;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>"UserBlocks" tablosu: (engelleyen, engellenen) benzersiz; "beni kim engellemiş" sorgusu için engellenen de indeksli.</summary>
public class UserBlockConfiguration : IEntityTypeConfiguration<UserBlock>
{
    /// <summary>Tabloyu tanımlar.</summary>
    public void Configure(EntityTypeBuilder<UserBlock> builder)
    {
        builder.ToTable("UserBlocks");
        // Engel kaldırılınca satır KALICI silinir (BlockRepository: ExecuteDelete) → yumuşak silinmiş satır benzersiz indeksi tıkamaz, yeniden engellenebilir.
        builder.HasIndex(b => new { b.BlockerId, b.BlockedId }).IsUnique();
        builder.HasIndex(b => b.BlockedId);
    }
}

/// <summary>"UserReports" tablosu: şikâyet edilen kişiye göre indeksli (yönetici "bu kişi kaç kez şikâyet edilmiş" diye bakar).</summary>
public class UserReportConfiguration : IEntityTypeConfiguration<UserReport>
{
    /// <summary>Tabloyu tanımlar.</summary>
    public void Configure(EntityTypeBuilder<UserReport> builder)
    {
        builder.ToTable("UserReports");
        builder.Property(r => r.Note).HasMaxLength(500);
        builder.HasIndex(r => r.ReportedUserId);
    }
}
