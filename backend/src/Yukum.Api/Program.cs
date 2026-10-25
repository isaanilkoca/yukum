using System.Diagnostics;
using System.Text;
using Asp.Versioning;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Scalar.AspNetCore;
using Serilog;
using Serilog.Context;
using Yukum.Api.Health;
using Yukum.Api.Json;
using Yukum.Api.Middleware;
using Yukum.Application;
using Yukum.Infrastructure;
using Yukum.Infrastructure.Identity;
using Yukum.Api.Validation;

// Program.cs = uygulamanın açılış planı. İki bölüm: (1) builder: hangi servisler var, (2) app: istek hangi sırayla işlenir.

// ===== 1) SERVİSLERİN KAYDI =====
// builder: uygulamanın KURULUM aşaması. Ayarlar (appsettings.json, user-secrets, ortam değişkenleri) burada otomatik yüklenir.
var builder = WebApplication.CreateBuilder(args);

// Loglama (Serilog): ayarlar appsettings.json'daki "Serilog" bölümünden okunur (konsol + günlük dosya).
// Serilog'u .NET'in varsayılan loglamasının yerine koyar. Logun nereye yazılacağı appsettings.json'daki "Serilog" bölümündedir.
builder.Host.UseSerilog((context, configuration) =>
    configuration.ReadFrom.Configuration(context.Configuration));

// Controller'lar + JSON kuralları (camelCase, enum string, UTC tarih) + geçersiz veri (400) cevabının ProblemDetails biçimi.
// AddControllers: [ApiController] ile işaretli sınıfları (AuthController, CitiesController) etkinleştirir.
builder.Services.AddControllers()
    // JSON kuralları: alan adları camelCase, enum'lar metin, tarihler UTC (bkz. Json/JsonSetup.cs).
    .AddJsonOptions(options => JsonSetup.Configure(options.JsonSerializerOptions))
    .ConfigureApiBehaviorOptions(options =>
        // Gövde bozuk JSON ya da tür uyuşmazlığı (örn. bilinmeyen enum) ise MVC'nin üreteceği 400 cevabı bizim Türkçe formata çevrilir.
        options.InvalidModelStateResponseFactory = ValidationProblemResponse.Create);
// Aynı JSON kuralları, controller dışındaki cevaplar (hata cevapları gibi) için de geçerli olsun.
builder.Services.ConfigureHttpJsonOptions(options => JsonSetup.Configure(options.SerializerOptions));

// Sürüm adreste: /api/v1/... Sürümsüz adres kabul edilmez. Kırıcı değişiklik = yeni sürüm (v2).
builder.Services.AddApiVersioning(options =>
    {
        // Sürüm belirtilmeyen yerde 1.0 sayılır.
        options.DefaultApiVersion = new ApiVersion(1, 0);
        // Cevaplara 'api-supported-versions' başlığı eklenir: istemci hangi sürümlerin var olduğunu görür.
        options.ReportApiVersions = true;
        // Sürüm adresin içinden okunur: /api/v1/... (başlıktan ya da sorgudan değil).
        options.ApiVersionReader = new UrlSegmentApiVersionReader();
    })
    .AddMvc()
    .AddApiExplorer(options =>
    {
        // OpenAPI belgeleri sürüm adıyla gruplanır ('v1').
        options.GroupNameFormat = "'v'V";
        // OpenAPI/Scalar'da {version} yerine gerçek sürüm (v1) yazılır.
        options.SubstituteApiVersionInUrl = true;
    })
    .AddOpenApi();
// Kimlik doğrulama: istekteki "Authorization: Bearer <jeton>" başlığı denetlenir. İmza anahtarı ve süre ayarları
// Jwt bölümünden gelir (anahtar user-secrets'ta). Yalnız HS256 kabul edilir; süresi dolmuş, yanlış imzalı,
// başka yayıncı/hedef için üretilmiş jetonlar reddedilir (401). "sub" kullanıcı, "role" rol olarak okunur.
// Kimlik doğrulama yöntemi olarak 'Bearer' (JWT jetonu) seçilir. Jetonun nasıl denetleneceği hemen aşağıda.
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();
builder.Services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
    .Configure<IOptions<JwtOptions>>((bearer, jwt) =>
    {
        // appsettings.json'daki "Jwt" bölümü + user-secrets'taki gizli SigningKey (JwtOptions sınıfına dolmuş hali).
        var settings = jwt.Value;
        // .NET'in 'sub' gibi kısa claim adlarını eski uzun adlara çevirmesi kapatılır; jetondaki adlar olduğu gibi kalır.
        bearer.MapInboundClaims = false;
        bearer.TokenValidationParameters = new TokenValidationParameters
        {
            // Jeton bizim API'miz tarafından mı üretilmiş? (Issuer)
            ValidateIssuer = true,
            ValidIssuer = settings.Issuer,
            // Jeton bu uygulama (iOS) için mi üretilmiş? (Audience)
            ValidateAudience = true,
            ValidAudience = settings.Audience,
            // İmza gerçekten bizim gizli anahtarımızla mı atılmış? Sahte jetonu bu yakalar.
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings.SigningKey)),
            // Yalnız HS256 kabul edilir: 'alg: none' ya da başka algoritmayla sahte jeton hilesi engellenir.
            ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
            // İmzasız jeton kabul edilmez.
            RequireSignedTokens = true,
            // Bitiş zamanı olmayan (sonsuz) jeton kabul edilmez.
            RequireExpirationTime = true,
            // Süresi dolmuş jeton reddedilir (jetonlar 15 dk yaşar).
            ValidateLifetime = true,
            // Sunucu ile istemci saati arasındaki küçük fark için 30 sn tolerans (varsayılan 5 dk fazla geniştir).
            ClockSkew = TimeSpan.FromSeconds(30),
            // Kullanıcı numarası jetondaki 'sub' claim'inden okunur.
            NameClaimType = "sub",
            // [Authorize(Roles = ...)] kontrolü jetondaki 'role' claim'ine bakar.
            RoleClaimType = "role"
        };
    });

builder.Services.AddApplication();     // handler'lar (iş kuralları), kendiliğinden bulunup kaydedilir
builder.Services.AddInfrastructure();  // veritabanı (SQL Server), repository'ler, saat servisi

// GET /health: uygulama ayakta mı ve veritabanına bağlanabiliyor mu?
builder.Services.AddHealthChecks()
    .AddCheck<DatabaseHealthCheck>("database");

// Hata yönetimi: yakalanmamış hata -> 500 ProblemDetails (iç detay sızmaz); her hata cevabına traceId eklenir.
// Kodun herhangi bir yerinde fırlatılan hata (NotFoundException, ConflictException...) GlobalExceptionHandler'a düşer.
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
// Hata cevapları standart ProblemDetails biçimindedir (title, status, detail); her birine izleme numarası (traceId) eklenir.
builder.Services.AddProblemDetails(options =>
    options.CustomizeProblemDetails = context =>
        context.ProblemDetails.Extensions["traceId"] =
            Activity.Current?.Id ?? context.HttpContext.TraceIdentifier);


// ===== 2) İSTEK İŞLEME SIRASI (üstten alta) =====
// Build: yukarıda kaydedilen servislerle uygulama nesnesi kurulur. Bundan sonrası İSTEK HATTI'dır (middleware): SIRA ÖNEMLİDİR.
var app = builder.Build();

// Her isteğin tüm log satırlarına, hata cevabındaki traceId ile aynı numarayı yazar.
// Basit bir ara katman: isteğe numara (traceId) bağlar, sonraki katmana geçer. Bu istek için yazılan her log satırı aynı numarayı taşır.
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

// HTTP isteğini HTTPS'e yönlendirir (geliştirmede http profilinde uyarı verir; bilinen konu, iOS bağlantısında netleşecek).
app.UseHttpsRedirection();
app.UseAuthentication();   // jetondan kullanıcıyı çıkarır
app.UseAuthorization();    // [Authorize] ve rol kurallarını uygular

// Controller'lardaki [Route] adreslerini isteklere bağlar.
app.MapControllers();
// GET /health: uygulama ayakta mı, veritabanına bağlanabiliyor mu?
app.MapHealthChecks("/health");

// Sunucuyu başlatır. Program burada bekler ve istekleri karşılar.
app.Run();

// Entegrasyon testlerinin (WebApplicationFactory) uygulamayı bulabilmesi için.
public partial class Program;
