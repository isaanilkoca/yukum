using System.Diagnostics;
using Asp.Versioning;
using Scalar.AspNetCore;
using Serilog;
using Serilog.Context;
using Yukum.Api.Health;
using Yukum.Api.Json;
using Yukum.Api.Middleware;
using Yukum.Application;
using Yukum.Infrastructure;
using Yukum.Api.Validation;

// Program.cs = uygulamanın açılış planı. İki bölüm: (1) builder: hangi servisler var, (2) app: istek hangi sırayla işlenir.

// ===== 1) SERVİSLERİN KAYDI =====
var builder = WebApplication.CreateBuilder(args);

// Loglama (Serilog): ayarlar appsettings.json'daki "Serilog" bölümünden okunur (konsol + günlük dosya).
builder.Host.UseSerilog((context, configuration) =>
    configuration.ReadFrom.Configuration(context.Configuration));

// Controller'lar + JSON kuralları (camelCase, enum string, UTC tarih) + geçersiz veri (400) cevabının ProblemDetails biçimi.
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
builder.Services.AddApplication();     // handler'lar (iş kuralları), kendiliğinden bulunup kaydedilir
builder.Services.AddInfrastructure();  // veritabanı (SQL Server), repository'ler, saat servisi

// GET /health: uygulama ayakta mı ve veritabanına bağlanabiliyor mu?
builder.Services.AddHealthChecks()
    .AddCheck<DatabaseHealthCheck>("database");

// Hata yönetimi: yakalanmamış hata -> 500 ProblemDetails (iç detay sızmaz); her hata cevabına traceId eklenir.
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails(options =>
    options.CustomizeProblemDetails = context =>
        context.ProblemDetails.Extensions["traceId"] =
            Activity.Current?.Id ?? context.HttpContext.TraceIdentifier);


// ===== 2) İSTEK İŞLEME SIRASI (üstten alta) =====
var app = builder.Build();

// Her isteğin tüm log satırlarına, hata cevabındaki traceId ile aynı numarayı yazar.
app.Use(async (context, next) =>
{
    using (LogContext.PushProperty("TraceId", Activity.Current?.TraceId.ToString() ?? context.TraceIdentifier))
        await next();
});

app.UseSerilogRequestLogging();  // her istek için tek satır log: yöntem, adres, durum kodu, süre

app.UseExceptionHandler();       // beklenmeyen hataları yakalar
app.UseStatusCodePages();        // 404 gibi boş cevapları ProblemDetails'e çevirir

// Scalar (API deneme sayfası) ve OpenAPI belgesi yalnız geliştirme ortamında açıktır: /scalar
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
