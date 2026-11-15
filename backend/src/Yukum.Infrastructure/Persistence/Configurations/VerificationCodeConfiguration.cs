using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Yukum.Domain.Accounts;

namespace Yukum.Infrastructure.Persistence.Configurations;

/// <summary>"VerificationCodes" tablosu: kullanıcının son kodunu bulmak için (kullanıcı, amaç) indeksli.</summary>
public class VerificationCodeConfiguration : IEntityTypeConfiguration<VerificationCode>
{
    /// <summary>Tabloyu tanımlar.</summary>
    public void Configure(EntityTypeBuilder<VerificationCode> builder)
    {
        builder.ToTable("VerificationCodes");
        builder.Property(c => c.CodeHash).HasMaxLength(64).IsRequired();
        builder.HasIndex(c => new { c.UserId, c.Purpose });
    }
}
