using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Domain.Common;

namespace Yukum.Infrastructure.Persistence;

public class Repository<T>(AppDbContext context) : IRepository<T> where T : BaseEntity
{
    private DbSet<T> Set => context.Set<T>();

    // FindAsync bilerek kullanılmaz: yumuşak silme filtresini atlar. FirstOrDefaultAsync filtreyi uygular.
    public Task<T?> GetByIdAsync(Guid id, bool asNoTracking = false, CancellationToken cancellationToken = default) =>
        Query(asNoTracking).FirstOrDefaultAsync(e => e.Id == id, cancellationToken);

    public async Task<IReadOnlyList<T>> ListAsync(
        Expression<Func<T, bool>>? predicate = null, bool asNoTracking = false, CancellationToken cancellationToken = default)
    {
        var query = Query(asNoTracking);
        if (predicate is not null) query = query.Where(predicate);
        return await query.ToListAsync(cancellationToken);
    }

    public Task<bool> AnyAsync(Expression<Func<T, bool>> predicate, CancellationToken cancellationToken = default) =>
        Set.AnyAsync(predicate, cancellationToken);

    public Task<int> CountAsync(Expression<Func<T, bool>>? predicate = null, CancellationToken cancellationToken = default) =>
        predicate is null ? Set.CountAsync(cancellationToken) : Set.CountAsync(predicate, cancellationToken);

    public void Add(T entity) => Set.Add(entity);

    public void Remove(T entity) => Set.Remove(entity);

    private IQueryable<T> Query(bool asNoTracking) => asNoTracking ? Set.AsNoTracking() : Set;
}
