using Microsoft.Extensions.Diagnostics.HealthChecks;
using Yukum.Infrastructure.Persistence;

namespace Yukum.Api.Health;

/// <summary>
/// <c>GET /health</c> için veritabanı kontrolü: SQL Server'a bağlanabiliyor muyuz?
/// Bağlanıyorsa "Healthy" (200); bağlanamıyorsa ya da bağlantı ayarı eksik/bozuksa "Unhealthy" (503).
/// Hata ayrıntısı cevaba yazılmaz, yalnız loga gider. İzleme sistemleri bu adresi düzenli yoklar.
/// </summary>
public sealed class DatabaseHealthCheck(IServiceScopeFactory scopes, ILogger<DatabaseHealthCheck> logger) : IHealthCheck
{
    /// <summary>Veritabanı bağlantısını dener.</summary>
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            // Sağlık kontrolü uygulama boyunca tek örnek yaşar; DbContext ise 'istek başına' olmalı. Bu yüzden her kontrolde geçici bir kapsam (scope) açılır.
            await using var scope = scopes.CreateAsyncScope();
            // Veritabanı nesnesini al.
            var database = scope.ServiceProvider.GetRequiredService<AppDbContext>().Database;

            // SQL Server'a gerçekten bağlanılabiliyor mu? Evet: 200 Healthy, hayır: 503 Unhealthy.
            return await database.CanConnectAsync(cancellationToken)
                ? HealthCheckResult.Healthy()
                : HealthCheckResult.Unhealthy("Veritabanına bağlanılamadı.");
        }
        // Bağlantı dizesi eksik/bozuksa ya da sunucu kapalıysa buraya düşer. Ayrıntı yalnız loga yazılır, cevaba değil.
        catch (Exception exception)
        {
            logger.LogError(exception, "Veritabanı sağlık kontrolü başarısız");
            return HealthCheckResult.Unhealthy("Veritabanı kontrolü başarısız.");
        }
    }
}
