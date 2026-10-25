using System.Text.Json;
using FluentValidation.Results;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Infrastructure;

namespace Yukum.Api.Validation;

/// <summary>
/// Gelen veri geçersizse (örn. e-posta biçimi bozuk) 400 cevabını ProblemDetails olarak üretir.
/// Hatalı alan adlarını JSON ile aynı biçime (camelCase) çevirir: <c>"Email"</c> → <c>"email"</c>, <c>"Address.City"</c> → <c>"address.city"</c>.
/// Böylece iOS, hata mesajını formdaki doğru kutunun altında doğrudan gösterebilir.
/// </summary>
public static class ValidationProblemResponse
{
    /// <summary>Geçersiz model durumundan 400 ProblemDetails cevabı üretir.</summary>
    public static IActionResult Create(ActionContext context)
    {
        var factory = context.HttpContext.RequestServices.GetRequiredService<ProblemDetailsFactory>();
        var original = factory.CreateValidationProblemDetails(context.HttpContext, context.ModelState);

        var errors = original.Errors.ToDictionary(e => ToCamelCase(e.Key), e => e.Value);
        var problem = new ValidationProblemDetails(errors)
        {
            Type = original.Type,
            Status = StatusCodes.Status400BadRequest,
            Title = "Doğrulama hatası",
            Detail = "Bir veya daha fazla alan geçersiz."
        };
        foreach (var extension in original.Extensions)
            problem.Extensions[extension.Key] = extension.Value;

        return new BadRequestObjectResult(problem) { ContentTypes = { "application/problem+json" } };
    }

    /// <summary>
    /// FluentValidation hatalarını aynı 400 biçimine çevirir (başlık "Doğrulama hatası", alan adları camelCase,
    /// örn. <c>vehicles[1].capacityKg</c>); iOS her iki kaynaktan gelen doğrulama hatasını aynı şekilde okur.
    /// </summary>
    /// <param name="failures">Doğrulama kurallarının bulduğu hatalar.</param>
    public static ValidationProblemDetails FromFailures(IEnumerable<ValidationFailure> failures)
    {
        var errors = failures
            .GroupBy(f => ToCamelCase(f.PropertyName))
            .ToDictionary(g => g.Key, g => g.Select(f => f.ErrorMessage).Distinct().ToArray());

        return new ValidationProblemDetails(errors)
        {
            Status = StatusCodes.Status400BadRequest,
            Title = "Doğrulama hatası",
            Detail = "Bir veya daha fazla alan geçersiz."
        };
    }

    private static string ToCamelCase(string path) =>
        string.Join('.', path.Split('.').Select(JsonNamingPolicy.CamelCase.ConvertName));
}
