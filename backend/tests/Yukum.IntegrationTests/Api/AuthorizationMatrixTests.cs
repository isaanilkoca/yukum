using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Time.Testing;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Api;

// YETKİ MATRİSİ: API'nin TÜM uçları uygulamanın kendisinden (EndpointDataSource) okunur ve kural olarak denetlenir.
// Amaç: biri yeni bir uç ekleyip [Authorize] yazmayı unutursa test kırılır (güvenli varsayılan: yetkisiz uç yok).
[Collection("SqlServer")]
public partial class AuthorizationMatrixTests(SqlServerFixture sql)
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 25, 9, 0, 0, TimeSpan.Zero);

    // Bilerek anonim olan uçlar (giriş yapmadan çağrılabilmeli). Liste dışında anonim uç kabul edilmez.
    private static readonly HashSet<string> AnonymousAllowList =
    [
        "POST api/v1/auth/login", "POST api/v1/auth/refresh", "POST api/v1/auth/logout",
        "POST api/v1/auth/register/shipper", "POST api/v1/auth/register/carrier",
        "GET api/v1/cities", "GET api/v1/cities/{cityId:int}/districts"
    ];

    // Uygulama uçları (testler için eklenen /test/ uçları ve OpenAPI/Scalar/health hariç).
    private sealed record Api(string Method, string Pattern, string[]? Roles, bool IsAnonymous);

    private static List<Api> ReadEndpoints(WebApplicationFactory<Program> factory) =>
        factory.Services.GetRequiredService<EndpointDataSource>().Endpoints.OfType<RouteEndpoint>()
            .Where(e => e.RoutePattern.RawText!.StartsWith("api/v{version:apiVersion}/") && !e.RoutePattern.RawText.Contains("/test/"))
            .SelectMany(e =>
            {
                var methods = e.Metadata.GetMetadata<HttpMethodMetadata>()!.HttpMethods;
                var pattern = e.RoutePattern.RawText!.Replace("{version:apiVersion}", "1");
                var auth = e.Metadata.GetOrderedMetadata<IAuthorizeData>();
                var roles = auth.Select(a => a.Roles).FirstOrDefault(r => !string.IsNullOrWhiteSpace(r))?.Split(',', StringSplitOptions.TrimEntries);
                var anonymous = e.Metadata.GetMetadata<IAllowAnonymous>() is not null;
                return methods.Select(m => new Api(m, pattern, roles, anonymous));
            }).ToList();

    [Fact]
    public void Every_endpoint_requires_authorization_unless_it_is_on_the_explicit_anonymous_list()
    {
        using var factory = new YukumApiFactory();
        var apis = ReadEndpoints(factory);
        Assert.True(apis.Count > 30, $"Uçlar okunamadı ya da çok az bulundu: {apis.Count}");   // test boşa geçmesin

        var anonymousNotListed = apis.Where(a => a.IsAnonymous && !AnonymousAllowList.Contains($"{a.Method} {a.Pattern}")).Select(a => $"{a.Method} {a.Pattern}").ToList();
        Assert.True(anonymousNotListed.Count == 0, "Listede olmayan anonim uç: " + string.Join(", ", anonymousNotListed));

        // Anonim olmayanlar mutlaka [Authorize] taşımalı. (IsAnonymous=false iken metadata yoksa uç herkese açıktır.)
        using var scope = factory.Services.CreateScope();
        var unprotected = factory.Services.GetRequiredService<EndpointDataSource>().Endpoints.OfType<RouteEndpoint>()
            .Where(e => e.RoutePattern.RawText!.StartsWith("api/v{version:apiVersion}/") && !e.RoutePattern.RawText.Contains("/test/"))
            .Where(e => e.Metadata.GetMetadata<IAllowAnonymous>() is null && !e.Metadata.GetOrderedMetadata<IAuthorizeData>().Any())
            .Select(e => e.RoutePattern.RawText!).ToList();
        Assert.True(unprotected.Count == 0, "[Authorize] yazılmamış uç: " + string.Join(", ", unprotected));
    }

    [Fact]
    public async Task Each_protected_endpoint_gives_401_to_anonymous_403_to_the_wrong_role_and_lets_the_right_role_through()
    {
        var database = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));
        using var baseFactory = new YukumApiFactory();
        using var factory = baseFactory.WithWebHostBuilder(b => b.UseSetting("ConnectionStrings:DefaultConnection", database.ConnectionString));
        using var client = factory.CreateClient();
        var tokens = new Dictionary<string, string> { ["Shipper"] = await Token(client, true), ["Carrier"] = await Token(client, false) };

        var failures = new List<string>();
        var checkedCount = 0;

        foreach (var api in ReadEndpoints(factory).Where(a => !a.IsAnonymous))
        {
            var url = "/" + GuidParameter().Replace(api.Pattern, Guid.NewGuid().ToString()); // {id:guid} yerine rastgele numara
            // Sorgu parametresi isteyen tek uç: emsal fiyat. Yetki, parametre denetiminden ÖNCE çalışır; yine de geçerli değerler veririz.
            if (url.Contains("price-reference")) url += "?fromCityId=33&toCityId=34&vehicleType=Truck";

            async Task<HttpStatusCode> Send(string? token)
            {
                var request = new HttpRequestMessage(new HttpMethod(api.Method), url);
                if (token is not null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
                if (api.Method is "POST" or "PUT") request.Content = JsonContent.Create(new { });
                return (await client.SendAsync(request)).StatusCode;
            }

            var label = $"{api.Method} {api.Pattern}";
            if (await Send(null) != HttpStatusCode.Unauthorized) failures.Add($"{label}: anonim 401 değil");
            foreach (var role in tokens.Keys)
            {
                var status = await Send(tokens[role]);
                var allowed = api.Roles is null || api.Roles.Contains(role);
                if (allowed && status is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden) failures.Add($"{label}: {role} geçmeliydi ama {(int)status}");
                if (!allowed && status != HttpStatusCode.Forbidden) failures.Add($"{label}: {role} 403 almalıydı ama {(int)status}");
            }
            checkedCount++;
        }

        Assert.True(checkedCount > 25, $"Çok az uç denetlendi: {checkedCount}");
        Assert.True(failures.Count == 0, string.Join(Environment.NewLine, failures));
    }

    [Fact]
    public async Task Responses_carry_the_security_headers()
    {
        using var factory = new YukumApiFactory();
        var response = await factory.CreateClient().GetAsync("/api/v1/test/sample"); // veritabanı gerektirmeyen test ucu (hata yolu başlıkları siler, bu yüzden başarılı bir cevap seçildi)
        Assert.Equal("nosniff", response.Headers.GetValues("X-Content-Type-Options").Single());
        Assert.Contains("no-store", response.Headers.CacheControl?.ToString());
    }

    private static async Task<string> Token(HttpClient c, bool shipper)
    {
        var n = Guid.NewGuid().ToString("N")[..8];
        var phone = "05" + Random.Shared.Next(300000000, 399999999);
        object body = shipper
            ? new { fullName = "Yuk Veren", email = $"m{n}@x.com", phone, password = "Abcdefg1", kvkkAccepted = true, termsAccepted = true }
            : new { fullName = "Tasimaci", email = $"m{n}@x.com", phone, password = "Abcdefg1", vehicles = new object[] { new { type = "Truck", capacityKg = 1000 } }, kvkkAccepted = true, termsAccepted = true };
        var reg = await c.PostAsJsonAsync(shipper ? "/api/v1/auth/register/shipper" : "/api/v1/auth/register/carrier", body);
        Assert.Equal(HttpStatusCode.Created, reg.StatusCode);
        var login = await c.PostAsJsonAsync("/api/v1/auth/login", new { emailOrPhone = $"m{n}@x.com", password = "Abcdefg1", deviceId = "d" + n, deviceName = "t" });
        return JsonDocument.Parse(await login.Content.ReadAsStringAsync()).RootElement.GetProperty("accessToken").GetString()!;
    }

    [GeneratedRegex(@"\{[a-zA-Z]+:guid\}")]
    private static partial Regex GuidParameter();
}
