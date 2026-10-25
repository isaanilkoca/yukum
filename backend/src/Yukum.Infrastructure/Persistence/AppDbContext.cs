using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using Yukum.Domain.Common;
using Yukum.Domain.Geography;

namespace Yukum.Infrastructure.Persistence;

/// <summary>
/// Uygulamanın veritabanıyla konuştuğu merkez sınıf (EF Core DbContext). Tüm tablolara ortak şu kuralları uygular:
/// <list type="bullet">
/// <item>Kaydederken <c>CreatedAt</c> / <c>UpdatedAt</c> otomatik (UTC) yazılır.</item>
/// <item><c>Remove</c> kaydı silmez, <c>IsDeleted = true</c> yapar (yumuşak silme); silinenler sorgularda otomatik gizlenir.</item>
/// <item><c>RowVersion</c> ile eşzamanlılık denetimi yapılır.</item>
/// </list>
/// Gerçek tablolar (il, ilçe, ilan...) bu sınıfa <c>DbSet</c> olarak eklenir.
/// </summary>
public class AppDbContext : DbContext
{
    /// <summary>Türkiye'nin 81 ili (sabit referans verisi, plaka koduyla).</summary>
    public DbSet<City> Cities => Set<City>();

    /// <summary>Türkiye'nin 973 ilçesi (sabit referans verisi).</summary>
    public DbSet<District> Districts => Set<District>();

    /// <summary>Zaman kaynağı. Doğrudan DateTime.UtcNow yerine bu kullanılır ki testlerde saat sabitlenebilsin.</summary>
    protected TimeProvider Time { get; }

    /// <summary>Uygulamanın kullandığı oluşturucu (DI burayı çağırır).</summary>
    public AppDbContext(DbContextOptions<AppDbContext> options, TimeProvider timeProvider)
        : this((DbContextOptions)options, timeProvider)
    {
    }

    /// <summary>Türetilmiş DbContext'ler (örn. testlerdeki) için oluşturucu.</summary>
    protected AppDbContext(DbContextOptions options, TimeProvider timeProvider) : base(options)
    {
        Time = timeProvider;
    }

    /// <summary>
    /// Model kurulurken <see cref="BaseEntity"/>'den türeyen her tabloya ortak kuralları ekler:
    /// RowVersion eşzamanlılık alanı ve "silinmemiş olanları getir" filtresi.
    /// </summary>
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Her tablonun kendi kuralları Persistence/Configurations klasöründeki sınıflardan toplanır.
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);

        // BaseEntity'den türeyen her tablo için ortak kurallar.
        foreach (var entityType in modelBuilder.Model.GetEntityTypes()
                     .Where(t => t.BaseType is null && typeof(BaseEntity).IsAssignableFrom(t.ClrType)))
        {
            var builder = modelBuilder.Entity(entityType.ClrType);
            builder.Property(nameof(BaseEntity.RowVersion)).IsRowVersion();
            builder.HasQueryFilter(NotDeletedFilter(entityType.ClrType));
        }
    }

    /// <summary>Her sorguya eklenen süzgeç: <c>e =&gt; !e.IsDeleted</c>.</summary>
    private static LambdaExpression NotDeletedFilter(Type entityType)
    {
        var parameter = Expression.Parameter(entityType, "e");
        var isDeleted = Expression.Property(parameter, nameof(BaseEntity.IsDeleted));
        return Expression.Lambda(Expression.Not(isDeleted), parameter);
    }

    /// <summary>Kaydetmeden önce zaman damgası ve yumuşak silme kurallarını uygular (eşzamanlı olmayan sürüm).</summary>
    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        ApplyAuditRules();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    /// <summary>Kaydetmeden önce zaman damgası ve yumuşak silme kurallarını uygular.</summary>
    public override Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
    {
        ApplyAuditRules();
        return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
    }

    /// <summary>
    /// Kaydetmeden hemen önce çalışır:
    /// yeni kayda <c>CreatedAt</c>, değişen kayda <c>UpdatedAt</c> yazar (<c>CreatedAt</c> korunur),
    /// silinecek kaydı gerçekten silmek yerine <c>IsDeleted = true</c> olarak günceller.
    /// </summary>
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
