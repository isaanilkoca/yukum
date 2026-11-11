using Microsoft.Extensions.Options;
using Yukum.Application.Notifications;
using Yukum.Infrastructure.Push;

namespace Yukum.Api.Background;

/// <summary>
/// Arka plan işçisi: belirli aralıkla bekleyen bildirimleri telefona yollar (PushDispatcher). Uygulama açılırken başlar, kapanırken durur.
/// Apns:Enabled=false ise hiç çalışmaz. Her turda yeni kapsam (scope) açılır: DbContext istek başına olduğu gibi tur başına üretilir.
/// </summary>
public sealed class PushWorker(IServiceScopeFactory scopes, IOptions<ApnsOptions> options, ILogger<PushWorker> logger) : BackgroundService
{
    /// <inheritdoc />
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.Value.Enabled)
        {
            logger.LogInformation("Push kapalı (Apns:Enabled=false); yalnız uygulama içi bildirimler çalışır.");
            return;
        }

        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(Math.Max(1, options.Value.PollSeconds)));
        do
        {
            try
            {
                await using var scope = scopes.CreateAsyncScope();
                var sent = await scope.ServiceProvider.GetRequiredService<PushDispatcher>().DispatchPendingAsync(stoppingToken);
                if (sent > 0) logger.LogInformation("{Count} push gönderildi", sent);
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                logger.LogError(exception, "Push turu başarısız; sonraki turda yeniden denenecek");   // işçi ölmez
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
