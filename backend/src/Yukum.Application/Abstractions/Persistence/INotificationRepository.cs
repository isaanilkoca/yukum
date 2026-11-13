using Yukum.Domain.Notifications;

namespace Yukum.Application.Abstractions.Persistence;

/// <summary>Bildirim okuma/okundu işaretleme. Yazma (yeni bildirim) olayı yapan handler'ın kendi işleminde IRepository ile yapılır.</summary>
public interface INotificationRepository
{
    /// <summary>Kullanıcının bildirimleri, en yeni üstte, sayfalı. Toplam sayıyı da döner.</summary>
    Task<(IReadOnlyList<Notification> Items, int Total)> ListAsync(Guid userId, int page, int pageSize, CancellationToken cancellationToken = default);

    /// <summary>Okunmamış bildirim sayısı (zil rozeti).</summary>
    Task<int> CountUnreadAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>Tek bildirimi okundu yapar. Başkasınınsa ya da yoksa false (404); zaten okunduysa true ve değişmez (idempotent).</summary>
    Task<bool> MarkReadAsync(Guid userId, Guid notificationId, DateTime now, CancellationToken cancellationToken = default);

    /// <summary>Okunmamışların hepsini okundu yapar. Kaç tane değiştiğini döner.</summary>
    Task<int> MarkAllReadAsync(Guid userId, DateTime now, CancellationToken cancellationToken = default);

    /// <summary>Tek bildirimi kalıcı siler. Yalnız sahibininkini; yoksa/başkasınınsa hiçbir şey silinmez. Kaç satır silindiğini döner (0 ya da 1).</summary>
    Task<int> DeleteAsync(Guid userId, Guid notificationId, CancellationToken cancellationToken = default);

    /// <summary>Henüz push'a işlenmemiş (PushedAt boş) bildirimler, en eski önce, en çok <paramref name="take"/> adet.</summary>
    Task<IReadOnlyList<Notification>> ListUnpushedAsync(int take, CancellationToken cancellationToken = default);

    /// <summary>Verilen bildirimleri "push'a işlendi" yapar (PushedAt doldurulur): bir daha gönderilmez.</summary>
    Task MarkPushedAsync(IReadOnlyCollection<Guid> ids, DateTime now, CancellationToken cancellationToken = default);

    /// <summary>Kullanıcının tüm bildirimlerini siler (hesap silme).</summary>
    Task DeleteUserDataAsync(Guid userId, CancellationToken cancellationToken = default);
}
