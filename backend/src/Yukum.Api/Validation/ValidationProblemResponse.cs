using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Infrastructure;

namespace Yukum.Api.Validation;

// Model doğrulama hatasını (400) ProblemDetails'e çevirir; alan adlarını JSON ile aynı biçime (camelCase) getirir:
// "Email" -> "email", "Address.City" -> "address.city". iOS formda doğrudan eşleştirebilsin diye.
public static class ValidationProblemResponse
{
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

    private static string ToCamelCase(string path) =>
        string.Join('.', path.Split('.').Select(JsonNamingPolicy.CamelCase.ConvertName));
}
