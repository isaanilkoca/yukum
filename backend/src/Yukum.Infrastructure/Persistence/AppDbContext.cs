using System.Linq.Expressions;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Yukum.Domain.Accounts;
using Yukum.Domain.Common;
using Yukum.Domain.Geography;
using Yukum.Infrastructure.Identity;

namespace Yukum.Infrastructure.Persistence;

/// <summary>
/// Uygulamanın veritabanıyla konuştuğu merkez sınıf (EF Core DbContext). Tüm tablolara ortak şu kuralları uygular:
/// <list type="bullet">
/// <item>Kaydederken <c>CreatedAt</c> / <c>UpdatedAt</c> otomatik (UTC) yazılır.</item>
/// <item><c>Remove</c> kaydı silmez, <c>IsDeleted = true</c> yapar (yumuşak silme); silinenler sorgularda otomatik gizlenir.</item>
/// <item><c>RowVersion</c> ile eşzamanlılık denetimi yapılır.</item>
/// </list>
/// Kullanıcı tabloları (Users, Roles...) ASP.NET Core Identity'den gelir; il, ilçe, profil, araç, jeton ve ileride ilan tabloları bu sınıfa <c>DbSet</c> olarak eklenir.
/// </summary>
// IdentityDbContext: kullanıcı/rol tablolarını hazır getirir. <AppUser, IdentityRole<Guid>, Guid> = kullanıcı sınıfı, rol sınıfı, anahtar türü (GUID).
public class AppDbContext : IdentityDbContext<AppUser, IdentityRole<Guid>, Guid>
{
    /// <summary>Yük Veren profilleri (kullanıcıyla bire bir).</summary>
    // DbSet<T> = veritabanındaki bir tabloya açılan kapı. Sorgular buradan başlar: context.Cities.Where(...). Aşağıdaki her satır bir tablo.
    public DbSet<ShipperProfile> ShipperProfiles => Set<ShipperProfile>();

    /// <summary>Taşımacı profilleri (kullanıcıyla bire bir).</summary>
    public DbSet<CarrierProfile> CarrierProfiles => Set<CarrierProfile>();

    /// <summary>Taşımacıların çalıştığı iller.</summary>
    public DbSet<CarrierServiceCity> CarrierServiceCities => Set<CarrierServiceCity>();

    /// <summary>Taşımacıların araçları.</summary>
    public DbSet<Vehicle> Vehicles => Set<Vehicle>();

    /// <summary>Oturum yenileme jetonları (yalnız hash'leri).</summary>
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    /// <summary>Türkiye'nin 81 ili (sabit referans verisi, plaka koduyla).</summary>
    public DbSet<City> Cities => Set<City>();

    /// <summary>Türkiye'nin 973 ilçesi (sabit referans verisi).</summary>
    public DbSet<District> Districts => Set<District>();

    /// <summary>Zaman kaynağı. Doğrudan DateTime.UtcNow yerine bu kullanılır ki testlerde saat sabitlenebilsin.</summary>
    // Zaman kaynağı. Testlerde saat sabitlenebilsin diye DateTime.UtcNow yerine bu kullanılır.
    protected TimeProvider Time { get; }

    /// <summary>Uygulamanın kullandığı oluşturucu (DI burayı çağırır).</summary>
    // Uygulamanın kullandığı yapıcı: seçenekler (SQL Server + bağlantı dizesi) ve saat servisi .NET'ten gelir.
    public AppDbContext(DbContextOptions<AppDbContext> options, TimeProvider timeProvider)
        : this((DbContextOptions)options, timeProvider)
    {
    }

    /// <summary>Türetilmiş DbContext'ler (örn. testlerdeki) için oluşturucu.</summary>
    // İkinci yapıcı: testlerdeki türetilmiş DbContext'ler için.
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
        // Önce Identity'nin kendi tablo tanımları kurulur.
        base.OnModelCreating(modelBuilder);

        // Her tablonun kendi kuralları Persistence/Configurations klasöründeki sınıflardan toplanır.
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);

        // Identity'nin hazır tablolarına AspNet... yerine rapordaki sade adlar verilir.
        modelBuilder.Entity<IdentityUserRole<Guid>>().ToTable("UserRoles");
        modelBuilder.Entity<IdentityUserClaim<Guid>>().ToTable("UserClaims");
        modelBuilder.Entity<IdentityUserLogin<Guid>>().ToTable("UserLogins");
        modelBuilder.Entity<IdentityUserToken<Guid>>().ToTable("UserTokens");
        modelBuilder.Entity<IdentityRoleClaim<Guid>>().ToTable("RoleClaims");

        // BaseEntity'den türeyen her tablo için ortak kurallar.
        // Bütün tablolar gezilir; BaseEntity'den türeyenlere (Vehicle, RefreshToken, ileride İlan, Teklif...) ortak kurallar eklenir.
        foreach (var entityType in modelBuilder.Model.GetEntityTypes()
                     .Where(t => t.BaseType is null && typeof(BaseEntity).IsAssignableFrom(t.ClrType)))
        {
            var builder = modelBuilder.Entity(entityType.ClrType);
            // RowVersion: SQL Server her değişiklikte bu sütunu kendisi günceller. İki kişi aynı kaydı aynı anda değiştirirse ikincisi DbUpdateConcurrencyException alır (çifte teklif kabulünü önler).
            builder.Property(nameof(BaseEntity.RowVersion)).IsRowVersion();
            // Genel süzgeç: her sorguya otomatik 'WHERE IsDeleted = 0' eklenir. Silinmişleri görmek için sorguda IgnoreQueryFilters() denir.
            builder.HasQueryFilter(NotDeletedFilter(entityType.ClrType));
        }
    }

    /// <summary>Her sorguya eklenen süzgeç: <c>e =&gt; !e.IsDeleted</c>.</summary>
    private static LambdaExpression NotDeletedFilter(Type entityType)
    {
        // Bu üç satır 'e => !e.IsDeleted' ifadesini kodla kurar (tablo türü çalışırken bilindiği için doğrudan lambda yazılamaz).
        var parameter = Expression.Parameter(entityType, "e");
        var isDeleted = Expression.Property(parameter, nameof(BaseEntity.IsDeleted));
        return Expression.Lambda(Expression.Not(isDeleted), parameter);
    }

    /// <summary>Kaydetmeden önce zaman damgası ve yumuşak silme kurallarını uygular (eşzamanlı olmayan sürüm).</summary>
    // Kaydetmeden hemen önce ApplyAuditRules çalışır (eşzamanlı sürüm; uygulamada asıl kullanılan aşağıdakidir).
    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        // Önce zaman damgası ve yumuşak silme kuralları uygulanır, sonra gerçek kayıt yapılır.
        ApplyAuditRules();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    /// <summary>Kaydetmeden önce zaman damgası ve yumuşak silme kurallarını uygular.</summary>
    // Eşzamansız sürüm: uygulamada hep bu çalışır.
    public override Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
    {
        ApplyAuditRules();
        return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
    }

    /// <summary>
    /// Kaydetmeden hemen önce çalışır:
    /// yeni kayda <c>CreatedAt</c>, değişen kayda <c>UpdatedAt</c> yazar (<c>CreatedAt</c> korunur),
    /// <see cref="BaseEntity"/> kaydı silinecekse gerçekten silmek yerine <c>IsDeleted = true</c> olarak günceller.
    /// </summary>
    private void ApplyAuditRules()
    {
        // Şu an (UTC). Aynı kayıtta tüm damgalar aynı anı taşır.
        var now = Time.GetUtcNow().UtcDateTime;

        // ChangeTracker: EF'in 'neler eklendi/değişti/silindi' listesi. Zaman damgası taşıyan her kayıt için bakılır.
        foreach (var entry in ChangeTracker.Entries<ITimestamped>())
        {
            switch (entry.State)
            {
                // Yeni kayıt → oluşturulma zamanı yazılır.
                case EntityState.Added:
                    entry.Entity.CreatedAt = now;
                    break;

                case EntityState.Modified:
                    // Değişen kayıtta oluşturulma zamanı ASLA değişmez (biri elle yazsa bile yok sayılır).
                    entry.Property(e => e.CreatedAt).IsModified = false;
                    // Değişen kayıt → son değişiklik zamanı yazılır.
                    entry.Entity.UpdatedAt = now;
                    break;

                // Yumuşak silme yalnız BaseEntity tabloları içindir; kullanıcı gibi diğer kayıtlar gerçekten silinir.
                case EntityState.Deleted when entry.Entity is BaseEntity entity:
                    // Silme komutu GÜNCELLEMEYE çevrilir: kayıt silinmez, IsDeleted = true olur (iz kalır).
                    entry.State = EntityState.Modified;
                    entity.IsDeleted = true;
                    entity.UpdatedAt = now;
                    break;
            }
        }
    }
}
