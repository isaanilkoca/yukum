using FluentValidation;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Yukum.Api.Validation;
using Yukum.Application.Common;

namespace Yukum.Api.Middleware;

/// <summary>
/// Kodun herhangi bir yerinde yakalanmamış bir hata çıkarsa devreye girer ve uygun HTTP cevabına çevirir.
/// <list type="table">
/// <item><term>400</term><description><see cref="ValidationException"/>: alan hataları, Türkçe mesajlarla.</description></item>
/// <item><term>401</term><description><see cref="InvalidCredentialsException"/>: kullanıcı/şifre hatalı (tek, genel mesaj).</description></item>
/// <item><term>403</term><description><see cref="ForbiddenException"/>: kimliği doğrulanmış ama bu işleme yetkisi yok.</description></item>
/// <item><term>404</term><description><see cref="NotFoundException"/>: istenen kayıt yok.</description></item>
/// <item><term>409</term><description><see cref="ConflictException"/>: mevcut kayıtla çakışma.</description></item>
/// <item><term>423</term><description><see cref="AccountLockedException"/>: hesap geçici kilitli (+ <c>Retry-After</c> başlığı).</description></item>
/// <item><term>500</term><description>Diğer her hata: sade mesaj. Asıl ayrıntı (tablo adı, kod satırı vb.) yalnız sunucu loguna yazılır, istemciye SIZMAZ.</description></item>
/// </list>
/// Beklenen durumların (yukarıdakiler) mesajları istemciye gösterilir, bu yüzden iç ayrıntı içermez.
/// </summary>
public sealed class GlobalExceptionHandler(
    IProblemDetailsService problemDetailsService,
    ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    /// <summary>Hatayı loglar ve istemciye ProblemDetails yazar.</summary>
    /// <returns><c>true</c>: hata işlendi, başka işleyiciye gerek yok.</returns>
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        if (exception is ValidationException validation)
        {
            // Beklenen durum (kullanıcı hatalı alan girdi). Alan değerleri (şifre!) loga yazılmaz, yalnız hangi alanlar.
            logger.LogInformation("Doğrulama hatası: {Path} - alanlar: {Fields}", httpContext.Request.Path,
                string.Join(", ", validation.Errors.Select(e => e.PropertyName).Distinct()));

            httpContext.Response.StatusCode = StatusCodes.Status400BadRequest;
            return await Write(httpContext, exception, ValidationProblemResponse.FromFailures(validation.Errors));
        }

        if (Describe(exception) is { } expected)
        {
            // Beklenen bir durum: hata değil, sade bilgi logu. Mesaj/kimlik (e-posta, telefon) loga yazılmaz.
            logger.LogInformation("Beklenen durum {Status} ({Type}): {Path}", expected.Status, exception.GetType().Name, httpContext.Request.Path);

            httpContext.Response.StatusCode = expected.Status;
            if (exception is AccountLockedException locked)
                httpContext.Response.Headers.RetryAfter = ((int)Math.Ceiling(locked.RetryAfter.TotalSeconds)).ToString();

            return await Write(httpContext, exception, new ProblemDetails
            {
                Status = expected.Status,
                Title = expected.Title,
                Detail = expected.Detail
            });
        }

        logger.LogError(exception, "Beklenmeyen hata: {Path}", httpContext.Request.Path);

        httpContext.Response.StatusCode = StatusCodes.Status500InternalServerError;
        return await Write(httpContext, exception, new ProblemDetails
        {
            Status = StatusCodes.Status500InternalServerError,
            Title = "Sunucu hatası",
            Detail = "Beklenmeyen bir hata oluştu. Lütfen daha sonra tekrar deneyin."
        });
    }

    /// <summary>İş kuralı hatalarını HTTP durumuna, başlığa ve kullanıcıya gösterilecek mesaja eşler; tanımadığı hata için <c>null</c>.</summary>
    private static (int Status, string Title, string Detail)? Describe(Exception exception) => exception switch
    {
        NotFoundException e => (StatusCodes.Status404NotFound, "Bulunamadı", e.Message),
        ConflictException e => (StatusCodes.Status409Conflict, "Çakışma", e.Message),
        InvalidCredentialsException e => (StatusCodes.Status401Unauthorized, "Giriş başarısız", e.Message),
        AccountLockedException e => (StatusCodes.Status423Locked, "Hesap geçici olarak kilitlendi", e.Message),
        ForbiddenException e => (StatusCodes.Status403Forbidden, "Erişim engellendi", e.Message),
        _ => null
    };

    private async ValueTask<bool> Write(HttpContext httpContext, Exception exception, ProblemDetails problem) =>
        await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            Exception = exception,
            ProblemDetails = problem
        });
}
