namespace Yukum.Application.Abstractions.Persistence;

/// <summary>Engellediğim bir kişi: kim, ne zaman.</summary>
public sealed record BlockedEntry(Guid UserId, DateTime BlockedAt);

/// <summary>
/// Engelleme kayıtları. Genel IRepository yerine özel sözleşme: kaldırma KALICI silme olmalı (yumuşak silme benzersiz indeksi tıkardı)
/// ve "iki yönden biri engellemiş mi" sorusu tek sorguda sorulur.
/// </summary>
public interface IBlockRepository
{
    /// <summary>Engeller. Zaten engelliyse hiçbir şey yapmaz (idempotent).</summary>
    Task BlockAsync(Guid blockerId, Guid blockedId, CancellationToken cancellationToken = default);

    /// <summary>Engeli kaldırır. Engelli değilse hiçbir şey yapmaz (idempotent).</summary>
    Task UnblockAsync(Guid blockerId, Guid blockedId, CancellationToken cancellationToken = default);

    /// <summary>İki kişiden BİRİ diğerini engellemiş mi (yön önemsiz).</summary>
    Task<bool> IsBlockedEitherWayAsync(Guid a, Guid b, CancellationToken cancellationToken = default);

    /// <summary>Kullanıcıyla arasında engel olan herkes (onun engellediği + onu engelleyen).</summary>
    Task<HashSet<Guid>> BlockedEitherWayIdsAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>Kullanıcının engellediği kişiler, en son engellenen üstte.</summary>
    Task<IReadOnlyList<BlockedEntry>> ListBlockedAsync(Guid blockerId, CancellationToken cancellationToken = default);

    /// <summary>Kullanıcının iki yöndeki tüm engel kayıtlarını siler (hesap silme).</summary>
    Task DeleteUserDataAsync(Guid userId, CancellationToken cancellationToken = default);
}
