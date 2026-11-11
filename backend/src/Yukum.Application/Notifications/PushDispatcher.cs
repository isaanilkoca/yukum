using Yukum.Application.Abstractions.Notifications;
using Yukum.Application.Abstractions.Persistence;

namespace Yukum.Application.Notifications;

/// <summary>
/// "Gönderilecekler kutusu"nu (outbox) boşaltır: PushedAt boş bildirimleri alır, sahibinin telefon(lar)ına push yollar, sonra işaretler.
/// Bildirim satırı olayla aynı işlemde yazıldığı için (bkz. NotificationFactory kullanan handler'lar) hiçbir olay kaybolmaz;
/// Apple'a gönderim yavaş/başarısız olsa bile kullanıcının isteği bundan etkilenmez, çünkü gönderim bu ayrı adımda yapılır.
/// </summary>
public sealed class PushDispatcher(INotificationRepository notifications, IDeviceTokenRepository devices, IPushSender sender, TimeProvider time)
{
    /// <summary>Bir turda işlenen en çok bildirim.</summary>
    public const int BatchSize = 50;

    /// <summary>Bundan eski bildirim telefona yollanmaz (bayat haber), yalnız işaretlenir. Uygulama içi listede yine görünür.</summary>
    public static readonly TimeSpan MaxAge = TimeSpan.FromHours(1);

    // FONKSİYON ROLÜ: ARKA PLAN İŞİ | Api/Background/PushWorker belirli aralıkla çağırır
    /// <summary>Bekleyen bildirimleri gönderir. Kaç push'un Apple tarafından kabul edildiğini döner.</summary>
    public async Task<int> DispatchPendingAsync(CancellationToken cancellationToken = default)
    {
        var pending = await notifications.ListUnpushedAsync(BatchSize, cancellationToken);
        if (pending.Count == 0) return 0;

        var now = time.GetUtcNow().UtcDateTime;
        var tokens = (await devices.ListForUsersAsync(pending.Select(n => n.UserId).Distinct().ToList(), cancellationToken))
            .ToLookup(d => d.UserId);
        var dead = new HashSet<string>();   // bu turda geçersiz çıkan jetonlar: aynı turda tekrar denenmez
        var done = new List<Guid>();
        var sent = 0;

        foreach (var n in pending)
        {
            var targets = tokens[n.UserId].Where(d => !dead.Contains(d.Token)).ToList();
            // Telefonu kayıtlı değilse ya da bildirim bayatsa gönderilecek bir şey yok: yalnız işaretle
            if (targets.Count == 0 || now - n.CreatedAt > MaxAge) { done.Add(n.Id); continue; }

            var badge = await notifications.CountUnreadAsync(n.UserId, cancellationToken);   // uygulama simgesindeki kırmızı sayı
            var retry = false;
            foreach (var device in targets)
            {
                var result = await sender.SendAsync(
                    new PushMessage(device.Token, device.Sandbox, n.Title, n.Body, badge, n.Id, n.Type.ToString(), n.ListingId, n.OfferId), cancellationToken);
                if (result == PushResult.Sent) sent++;
                else if (result == PushResult.InvalidToken)
                {
                    dead.Add(device.Token);
                    await devices.RemoveByTokenAsync(device.Token, cancellationToken);   // Apple: bu adres artık yok
                }
                else retry = true;   // geçici hata: işaretleme, sonraki turda yeniden dene
            }
            if (!retry) done.Add(n.Id);
        }

        if (done.Count > 0) await notifications.MarkPushedAsync(done, now, cancellationToken);
        return sent;
    }
}
