using Yukum.Application.Abstractions.Persistence;

namespace Yukum.Infrastructure.Persistence;

// EF Core'un SaveChanges çağrısı zaten tek bir transaction'dır; birim bunu uygulama katmanına açar.
public class UnitOfWork(AppDbContext context) : IUnitOfWork
{
    public Task<int> SaveChangesAsync(CancellationToken cancellationToken = default) =>
        context.SaveChangesAsync(cancellationToken);
}
