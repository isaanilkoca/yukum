using Microsoft.EntityFrameworkCore;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Domain.Accounts;

namespace Yukum.Infrastructure.Persistence;

/// <summary><see cref="IBlockRepository"/>'nin EF Core uygulaması. Yapı EngagementRepository'deki favorilerle aynı (idempotent ekle / kalıcı sil).</summary>
public class BlockRepository(AppDbContext context) : IBlockRepository
{
    /// <inheritdoc />
    public async Task BlockAsync(Guid blockerId, Guid blockedId, CancellationToken cancellationToken = default)
    {
        if (await context.Set<UserBlock>().AnyAsync(b => b.BlockerId == blockerId && b.BlockedId == blockedId, cancellationToken)) return; // zaten engelli
        var block = new UserBlock { BlockerId = blockerId, BlockedId = blockedId };
        context.Add(block);
        try { await context.SaveChangesAsync(cancellationToken); }
        catch (DbUpdateException) { context.Entry(block).State = EntityState.Detached; } // iki istek aynı anda: benzersiz indeks ikincisini durdurur = "zaten var"
    }

    /// <inheritdoc />
    public Task UnblockAsync(Guid blockerId, Guid blockedId, CancellationToken cancellationToken = default) =>
        // ExecuteDelete: SELECT'siz tek DELETE, satır yoksa 0 satır (idempotent). Yumuşak silme değil: aynı kişi yeniden engellenebilsin.
        context.Set<UserBlock>().Where(b => b.BlockerId == blockerId && b.BlockedId == blockedId).ExecuteDeleteAsync(cancellationToken);

    /// <inheritdoc />
    public Task<bool> IsBlockedEitherWayAsync(Guid a, Guid b, CancellationToken cancellationToken = default) =>
        // SQL: SELECT CASE WHEN EXISTS (... WHERE (BlockerId=@a AND BlockedId=@b) OR (BlockerId=@b AND BlockedId=@a)) ...
        context.Set<UserBlock>().AnyAsync(x => (x.BlockerId == a && x.BlockedId == b) || (x.BlockerId == b && x.BlockedId == a), cancellationToken);

    /// <inheritdoc />
    public async Task<HashSet<Guid>> BlockedEitherWayIdsAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var ids = await context.Set<UserBlock>().AsNoTracking()
            .Where(b => b.BlockerId == userId || b.BlockedId == userId)
            .Select(b => b.BlockerId == userId ? b.BlockedId : b.BlockerId) // karşı taraf
            .ToListAsync(cancellationToken);
        return ids.ToHashSet();
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<BlockedEntry>> ListBlockedAsync(Guid blockerId, CancellationToken cancellationToken = default) =>
        await context.Set<UserBlock>().AsNoTracking().Where(b => b.BlockerId == blockerId)
            .OrderByDescending(b => b.CreatedAt).Select(b => new BlockedEntry(b.BlockedId, b.CreatedAt)).ToListAsync(cancellationToken);

    /// <inheritdoc />
    public Task DeleteUserDataAsync(Guid userId, CancellationToken cancellationToken = default) =>
        context.Set<UserBlock>().Where(b => b.BlockerId == userId || b.BlockedId == userId).ExecuteDeleteAsync(cancellationToken);
}
