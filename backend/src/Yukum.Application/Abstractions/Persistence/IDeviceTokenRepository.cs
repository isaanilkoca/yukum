using Yukum.Domain.Notifications;

namespace Yukum.Application.Abstractions.Persistence;

/// <summary>Push cihaz jetonlarının saklanması.</summary>
public interface IDeviceTokenRepository
{
    /// <summary>Jetonu bu kullanıcıya kaydeder. Jeton zaten varsa sahibi/cihazı güncellenir (idempotent); aynı cihazın eski jetonu silinir.</summary>
    Task UpsertAsync(Guid userId, string deviceId, string token, bool sandbox, CancellationToken cancellationToken = default);

    /// <summary>Verilen kullanıcıların tüm cihaz jetonları.</summary>
    Task<IReadOnlyList<DeviceToken>> ListForUsersAsync(IReadOnlyCollection<Guid> userIds, CancellationToken cancellationToken = default);

    /// <summary>Kullanıcının bu cihazdaki jetonunu siler (çıkış). Yoksa hiçbir şey yapmaz.</summary>
    Task RemoveForDeviceAsync(Guid userId, string deviceId, CancellationToken cancellationToken = default);

    /// <summary>Jetonu siler (Apple "bu jeton artık geçersiz" dediğinde).</summary>
    Task RemoveByTokenAsync(string token, CancellationToken cancellationToken = default);

    /// <summary>Kullanıcının tüm jetonlarını siler (hesap silme).</summary>
    Task DeleteUserDataAsync(Guid userId, CancellationToken cancellationToken = default);
}
