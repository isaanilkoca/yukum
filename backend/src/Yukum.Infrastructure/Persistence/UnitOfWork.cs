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
        // EF, bekleyen TÜM değişiklikleri tek veritabanı işleminde (transaction) gönderir; biri hata verirse hepsi geri alınır.
        context.SaveChangesAsync(cancellationToken);

    /// <inheritdoc />
    public async Task ExecuteInTransactionAsync(Func<CancellationToken, Task> work, CancellationToken cancellationToken = default)
    {
        // BeginTransactionAsync: açık işlem başlatır | await using: blok bitince işlem kapanır (Commit çağrılmadıysa geri alınır)
        await using var transaction = await context.Database.BeginTransactionAsync(cancellationToken);
        await work(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
    }
}
