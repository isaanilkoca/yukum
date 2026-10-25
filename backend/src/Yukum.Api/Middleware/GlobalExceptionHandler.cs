using FluentValidation;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Yukum.Api.Validation;
using Yukum.Application.Common;

namespace Yukum.Api.Middleware;

/// <summary>
/// Kodun herhangi bir yerinde yakalanmamış bir hata çıkarsa devreye girer.
/// <list type="bullet">
/// <item>İş kuralı "kayıt yok" derse (<see cref="NotFoundException"/>) 404, "çakışma" derse (<see cref="ConflictException"/>) 409,
/// doğrulama kuralları ihlal edilirse (<see cref="ValidationException"/>) 400 ProblemDetails döner; mesajlar istemciye gösterilir.</item>
/// <item>Diğer her hata için sade bir 500 cevabı (ProblemDetails + traceId) döner. Asıl hata ayrıntısı (tablo adı, kod satırı vb.)
/// yalnızca sunucu loguna yazılır, istemciye SIZMAZ (güvenlik).</item>
/// </list>
/// </summary>
public sealed class GlobalExceptionHandler(
    IProblemDetailsService problemDetailsService,
    ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    /// <summary>Hatayı loglar ve istemciye 400, 404, 409 ya da 500 ProblemDetails yazar.</summary>
    /// <returns><c>true</c>: hata işlendi, başka işleyiciye gerek yok.</returns>
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        if (exception is NotFoundException notFound)
        {
            // Beklenen bir durum (istemci olmayan kaydı istedi): hata değil, sade bilgi logu.
            logger.LogInformation("Kayıt bulunamadı: {Path} - {Message}", httpContext.Request.Path, notFound.Message);

            httpContext.Response.StatusCode = StatusCodes.Status404NotFound;

            return await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
            {
                HttpContext = httpContext,
                Exception = exception,
                ProblemDetails = new ProblemDetails
                {
                    Status = StatusCodes.Status404NotFound,
                    Title = "Bulunamadı",
                    Detail = notFound.Message
                }
            });
        }

        if (exception is ConflictException conflict)
        {
            logger.LogInformation("Çakışma: {Path} - {Message}", httpContext.Request.Path, conflict.Message);

            httpContext.Response.StatusCode = StatusCodes.Status409Conflict;

            return await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
            {
                HttpContext = httpContext,
                Exception = exception,
                ProblemDetails = new ProblemDetails
                {
                    Status = StatusCodes.Status409Conflict,
                    Title = "Çakışma",
                    Detail = conflict.Message
                }
            });
        }

        if (exception is ValidationException validation)
        {
            // Beklenen durum (kullanıcı hatalı alan girdi). Alan değerleri (şifre!) loga yazılmaz, yalnız hangi alanlar.
            logger.LogInformation("Doğrulama hatası: {Path} - alanlar: {Fields}", httpContext.Request.Path,
                string.Join(", ", validation.Errors.Select(e => e.PropertyName).Distinct()));

            httpContext.Response.StatusCode = StatusCodes.Status400BadRequest;

            return await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
            {
                HttpContext = httpContext,
                Exception = exception,
                ProblemDetails = ValidationProblemResponse.FromFailures(validation.Errors)
            });
        }

        logger.LogError(exception, "Beklenmeyen hata: {Path}", httpContext.Request.Path);

        httpContext.Response.StatusCode = StatusCodes.Status500InternalServerError;

        return await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            Exception = exception,
            ProblemDetails = new ProblemDetails
            {
                Status = StatusCodes.Status500InternalServerError,
                Title = "Sunucu hatası",
                Detail = "Beklenmeyen bir hata oluştu. Lütfen daha sonra tekrar deneyin."
            }
        });
    }
}
