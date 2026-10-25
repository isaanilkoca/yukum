using Yukum.Application.Abstractions.Persistence;

namespace Yukum.Infrastructure.Persistence;

/// <summary>
/// <see cref="IUnitOfWork"/>'un EF Core uygulaması. EF Core'un SaveChanges çağrısı zaten tek bir transaction'dır;
/// bu sınıf onu uygulama katmanına EF'i göstermeden açar.
/// </summary>
public class UnitOfWork(AppDbContext context) : IUnitOfWork
{
    /// <inheritdoc />
    public Task<int> SaveChangesAsync(CancellationToken cancellationToken = default) =>
        context.SaveChangesAsync(cancellationToken);
}
