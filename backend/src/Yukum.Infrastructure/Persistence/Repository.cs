using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Domain.Common;

namespace Yukum.Infrastructure.Persistence;

/// <summary>
/// <see cref="IRepository{T}"/>'in EF Core uygulaması. Yumuşak silme filtresi <see cref="AppDbContext"/>'te olduğu için
/// tüm metotlar silinmiş kayıtları otomatik gizler.
/// </summary>
// Generic sınıf: T yerine Vehicle, RefreshToken... gelebilir; her tablo için ayrı yazmaya gerek kalmaz (Swift'teki generic'lerle aynı fikir).
public class Repository<T>(AppDbContext context) : IRepository<T> where T : BaseEntity
{
    // T tablosunun kapısı.
    private DbSet<T> Set => context.Set<T>();

    // FindAsync bilerek kullanılmaz: yumuşak silme filtresini atlar. FirstOrDefaultAsync filtreyi uygular.
    /// <inheritdoc />
    public Task<T?> GetByIdAsync(Guid id, bool asNoTracking = false, CancellationToken cancellationToken = default) =>
        // İlk eşleşen kayıt ya da null. SQL: SELECT TOP 1 ... WHERE Id = @id. Yumuşak silinmişler genel süzgeçle zaten elenir.
        Query(asNoTracking).FirstOrDefaultAsync(e => e.Id == id, cancellationToken);

    /// <inheritdoc />
    public async Task<IReadOnlyList<T>> ListAsync(
        Expression<Func<T, bool>>? predicate = null, bool asNoTracking = false, CancellationToken cancellationToken = default)
    {
        // Sorguyu hazırla (henüz çalışmadı, yalnız tarif).
        var query = Query(asNoTracking);
        // Koşul verildiyse WHERE olarak ekle.
        if (predicate is not null) query = query.Where(predicate);
        // Sorgu İŞTE BURADA çalışır: SQL gönderilir, sonuç listeye alınır.
        return await query.ToListAsync(cancellationToken);
    }

    /// <inheritdoc />
    public Task<bool> AnyAsync(Expression<Func<T, bool>> predicate, CancellationToken cancellationToken = default) =>
        // SQL: EXISTS (en az bir kayıt var mı?).
        Set.AnyAsync(predicate, cancellationToken);

    /// <inheritdoc />
    public Task<int> CountAsync(Expression<Func<T, bool>>? predicate = null, CancellationToken cancellationToken = default) =>
        // Koşul yoksa hepsini say, varsa koşullu say (SQL: COUNT).
        predicate is null ? Set.CountAsync(cancellationToken) : Set.CountAsync(predicate, cancellationToken);

    /// <inheritdoc />
    // Takibe alır; SaveChanges çağrılınca INSERT gider.
    public void Add(T entity) => Set.Add(entity);

    /// <inheritdoc />
    // Silme işareti koyar; AppDbContext bunu 'IsDeleted = true' güncellemesine çevirir.
    public void Remove(T entity) => Set.Remove(entity);

    /// <summary>İzleme (tracking) açık ya da kapalı temel sorgu.</summary>
    // AsNoTracking: EF değişiklik takibi yapmaz → yalnız okuma için daha hızlı ve daha az bellek.
    private IQueryable<T> Query(bool asNoTracking) => asNoTracking ? Set.AsNoTracking() : Set;
}
