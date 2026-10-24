using System.Linq.Expressions;
using Yukum.Domain.Common;

namespace Yukum.Application.Abstractions.Persistence;

// İnce, genel veri erişimi. Karmaşık sorgular (filtre, sayfalama, konum) ilgili özel repository'ye yazılır.
// Okuma amaçlı çağrılarda asNoTracking: true kullanılır (daha hızlı); değiştirilecek kayıtlar izlenerek alınır,
// değişiklik IUnitOfWork.SaveChangesAsync ile kaydedilir (ayrı bir Update çağrısı gerekmez).
// Yumuşak silinmiş (IsDeleted) kayıtlar hiçbir metotta dönmez.
public interface IRepository<T> where T : BaseEntity
{
    Task<T?> GetByIdAsync(Guid id, bool asNoTracking = false, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<T>> ListAsync(
        Expression<Func<T, bool>>? predicate = null, bool asNoTracking = false, CancellationToken cancellationToken = default);

    Task<bool> AnyAsync(Expression<Func<T, bool>> predicate, CancellationToken cancellationToken = default);

    Task<int> CountAsync(Expression<Func<T, bool>>? predicate = null, CancellationToken cancellationToken = default);

    void Add(T entity);

    // Kaydı silmez, IsDeleted = true yapar (AppDbContext).
    void Remove(T entity);
}
