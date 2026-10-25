using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Domain.Common;

namespace Yukum.Infrastructure.Persistence;

/// <summary>
/// <see cref="IRepository{T}"/>'in EF Core uygulaması. Yumuşak silme filtresi <see cref="AppDbContext"/>'te olduğu için
/// tüm metotlar silinmiş kayıtları otomatik gizler.
/// </summary>
public class Repository<T>(AppDbContext context) : IRepository<T> where T : BaseEntity
{
    private DbSet<T> Set => context.Set<T>();

    // FindAsync bilerek kullanılmaz: yumuşak silme filtresini atlar. FirstOrDefaultAsync filtreyi uygular.
    /// <inheritdoc />
    public Task<T?> GetByIdAsync(Guid id, bool asNoTracking = false, CancellationToken cancellationToken = default) =>
        Query(asNoTracking).FirstOrDefaultAsync(e => e.Id == id, cancellationToken);

    /// <inheritdoc />
    public async Task<IReadOnlyList<T>> ListAsync(
        Expression<Func<T, bool>>? predicate = null, bool asNoTracking = false, CancellationToken cancellationToken = default)
    {
        var query = Query(asNoTracking);
        if (predicate is not null) query = query.Where(predicate);
        return await query.ToListAsync(cancellationToken);
    }

    /// <inheritdoc />
    public Task<bool> AnyAsync(Expression<Func<T, bool>> predicate, CancellationToken cancellationToken = default) =>
        Set.AnyAsync(predicate, cancellationToken);

    /// <inheritdoc />
    public Task<int> CountAsync(Expression<Func<T, bool>>? predicate = null, CancellationToken cancellationToken = default) =>
        predicate is null ? Set.CountAsync(cancellationToken) : Set.CountAsync(predicate, cancellationToken);

    /// <inheritdoc />
    public void Add(T entity) => Set.Add(entity);

    /// <inheritdoc />
    public void Remove(T entity) => Set.Remove(entity);

    /// <summary>İzleme (tracking) açık ya da kapalı temel sorgu.</summary>
    private IQueryable<T> Query(bool asNoTracking) => asNoTracking ? Set.AsNoTracking() : Set;
}
