using Microsoft.Extensions.Diagnostics.HealthChecks;
using Yukum.Infrastructure.Persistence;

namespace Yukum.Api.Health;

// Veritabanına bağlanabiliyor mu? Ayar eksik/bozuk dahil her hata "Unhealthy" (503) olur; ayrıntı yalnız loga gider.
public sealed class DatabaseHealthCheck(IServiceScopeFactory scopes, ILogger<DatabaseHealthCheck> logger) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            await using var scope = scopes.CreateAsyncScope();
            var database = scope.ServiceProvider.GetRequiredService<AppDbContext>().Database;

            return await database.CanConnectAsync(cancellationToken)
                ? HealthCheckResult.Healthy()
                : HealthCheckResult.Unhealthy("Veritabanına bağlanılamadı.");
        }
        catch (Exception exception)
        {
            logger.LogError(exception, "Veritabanı sağlık kontrolü başarısız");
            return HealthCheckResult.Unhealthy("Veritabanı kontrolü başarısız.");
        }
    }
}
