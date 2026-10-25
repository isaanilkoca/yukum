using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace Yukum.Api.Middleware;

/// <summary>
/// Kodun herhangi bir yerinde yakalanmamış bir hata çıkarsa devreye girer.
/// İstemciye sade bir 500 cevabı (ProblemDetails + traceId) döner. Asıl hata ayrıntısı (tablo adı, kod satırı vb.)
/// yalnızca sunucu loguna yazılır, istemciye SIZMAZ (güvenlik).
/// </summary>
public sealed class GlobalExceptionHandler(
    IProblemDetailsService problemDetailsService,
    ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    /// <summary>Hatayı loglar ve istemciye 500 ProblemDetails yazar.</summary>
    /// <returns><c>true</c>: hata işlendi, başka işleyiciye gerek yok.</returns>
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
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
