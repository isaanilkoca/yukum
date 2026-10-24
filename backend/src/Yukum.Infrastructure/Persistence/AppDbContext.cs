using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using Yukum.Domain.Common;

namespace Yukum.Infrastructure.Persistence;

public class AppDbContext : DbContext
{
    protected TimeProvider Time { get; }

    public AppDbContext(DbContextOptions<AppDbContext> options, TimeProvider timeProvider)
        : this((DbContextOptions)options, timeProvider)
    {
    }

    // Test DbContext'leri gibi türetilmiş sınıflar için.
    protected AppDbContext(DbContextOptions options, TimeProvider timeProvider) : base(options)
    {
        Time = timeProvider;
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // BaseEntity'den türeyen her tablo için ortak kurallar.
        foreach (var entityType in modelBuilder.Model.GetEntityTypes()
                     .Where(t => t.BaseType is null && typeof(BaseEntity).IsAssignableFrom(t.ClrType)))
        {
            var builder = modelBuilder.Entity(entityType.ClrType);
            builder.Property(nameof(BaseEntity.RowVersion)).IsRowVersion();
            builder.HasQueryFilter(NotDeletedFilter(entityType.ClrType));
        }
    }

    // e => !e.IsDeleted
    private static LambdaExpression NotDeletedFilter(Type entityType)
    {
        var parameter = Expression.Parameter(entityType, "e");
        var isDeleted = Expression.Property(parameter, nameof(BaseEntity.IsDeleted));
        return Expression.Lambda(Expression.Not(isDeleted), parameter);
    }

    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        ApplyAuditRules();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    public override Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
    {
        ApplyAuditRules();
        return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
    }

    // Kaydetmeden hemen önce: zaman damgaları (UTC) ve yumuşak silme.
    private void ApplyAuditRules()
    {
        var now = Time.GetUtcNow().UtcDateTime;

        foreach (var entry in ChangeTracker.Entries<BaseEntity>())
        {
            switch (entry.State)
            {
                case EntityState.Added:
                    entry.Entity.CreatedAt = now;
                    break;

                case EntityState.Modified:
                    entry.Property(e => e.CreatedAt).IsModified = false;
                    entry.Entity.UpdatedAt = now;
                    break;

                case EntityState.Deleted:
                    entry.State = EntityState.Modified;
                    entry.Entity.IsDeleted = true;
                    entry.Entity.UpdatedAt = now;
                    break;
            }
        }
    }
}
