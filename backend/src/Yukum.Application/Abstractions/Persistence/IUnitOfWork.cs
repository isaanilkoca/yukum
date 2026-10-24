namespace Yukum.Application.Abstractions.Persistence;

// Birden çok repository'de yapılan değişiklikleri TEK işlemde (transaction) kaydeder: ya hepsi olur ya hiçbiri.
public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
