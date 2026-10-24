using System.Diagnostics;
using Asp.Versioning;
using Scalar.AspNetCore;
using Serilog;
using Serilog.Context;
using Yukum.Api.Json;
using Yukum.Api.Middleware;
using Yukum.Api.Validation;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((context, configuration) =>
    configuration.ReadFrom.Configuration(context.Configuration));

builder.Services.AddControllers()
    .AddJsonOptions(options => JsonSetup.Configure(options.JsonSerializerOptions))
    .ConfigureApiBehaviorOptions(options =>
        options.InvalidModelStateResponseFactory = ValidationProblemResponse.Create);
builder.Services.ConfigureHttpJsonOptions(options => JsonSetup.Configure(options.SerializerOptions));

// Sürüm adreste: /api/v1/... Sürümsüz adres kabul edilmez. Kırıcı değişiklik = yeni sürüm (v2).
builder.Services.AddApiVersioning(options =>
    {
        options.DefaultApiVersion = new ApiVersion(1, 0);
        options.ReportApiVersions = true;
        options.ApiVersionReader = new UrlSegmentApiVersionReader();
    })
    .AddMvc()
    .AddApiExplorer(options =>
    {
        options.GroupNameFormat = "'v'V";
        options.SubstituteApiVersionInUrl = true;
    })
    .AddOpenApi();
builder.Services.AddHealthChecks();

builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails(options =>
    options.CustomizeProblemDetails = context =>
        context.ProblemDetails.Extensions["traceId"] =
            Activity.Current?.Id ?? context.HttpContext.TraceIdentifier);

var app = builder.Build();

// Her isteğin tüm log satırlarına, hata cevabındaki traceId ile aynı numarayı yazar.
app.Use(async (context, next) =>
{
    using (LogContext.PushProperty("TraceId", Activity.Current?.TraceId.ToString() ?? context.TraceIdentifier))
        await next();
});

app.UseSerilogRequestLogging();

app.UseExceptionHandler();
app.UseStatusCodePages();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi().WithDocumentPerVersion();
    app.MapScalarApiReference();
}

app.UseHttpsRedirection();
app.UseAuthorization();

app.MapControllers();
app.MapHealthChecks("/health");

app.Run();

// Entegrasyon testlerinin (WebApplicationFactory) uygulamayı bulabilmesi için.
public partial class Program;
