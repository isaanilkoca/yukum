using Microsoft.Extensions.Logging;
using Yukum.Application.Abstractions.Identity;

namespace Yukum.Infrastructure.Identity;

/// <summary>
/// GELİŞTİRME e-posta göndericisi (15 Kasım): e-postayı göndermez, API günlüğüne yazar
/// (backend/src/Yukum.Api/logs/yukum-YYYYMMDD.log ve konsol). Kod oradan okunup telefonda denenir.
/// CANLIDA KULLANILMAZ: kod günlüğe düşerse günlüğü okuyan herkes hesabı ele geçirir → DependencyInjection yalnız Development ortamında kaydeder.
/// Alan adı + Resend hazır olunca yerine ResendEmailSender yazılır (IEmailSender aynı kalır).
/// </summary>
public sealed class LogEmailSender(ILogger<LogEmailSender> logger) : IEmailSender
{
    /// <inheritdoc />
    public Task SendAsync(string to, string subject, string body, CancellationToken cancellationToken = default)
    {
        logger.LogWarning("📧 GELİŞTİRME E-POSTASI (gönderilmedi) → {To} | {Subject}\n{Body}", to, subject, body);
        return Task.CompletedTask;
    }
}
