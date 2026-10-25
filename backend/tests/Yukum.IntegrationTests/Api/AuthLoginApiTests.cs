using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Time.Testing;
using Microsoft.IdentityModel.JsonWebTokens;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Api;

// POST /api/v1/auth/login ve jetonun korumalı uçlarda kullanımı: gerçek API + gerçek SQL Server, uçtan uca.
[Collection("SqlServer")]
public class AuthLoginApiTests(SqlServerFixture sql)
{
    private const string Password = "Abcdefg1";

    private async Task<(HttpClient Client, TestDatabase Db)> StartAsync()
    {
        var database = await sql.CreateDatabaseAsync(new FakeTimeProvider());
        var client = new YukumApiFactory()
            .WithWebHostBuilder(builder => builder.UseSetting("ConnectionStrings:DefaultConnection", database.ConnectionString))
            .CreateClient();
        return (client, database);
    }

    private static async Task<JsonElement> ReadJson(HttpResponseMessage response) =>
        JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement;

    private static async Task RegisterShipperAsync(HttpClient client, string email = "ali@x.com", string phone = "0532 123 45 67") =>
        Assert.Equal(HttpStatusCode.Created, (await client.PostAsJsonAsync("/api/v1/auth/register/shipper", new
        {
            fullName = "Ali Veli", email, phone, password = Password, cityId = 33, kvkkAccepted = true
        })).StatusCode);

    private static async Task RegisterCarrierAsync(HttpClient client, string email = "veli@x.com", string phone = "0533 222 11 00") =>
        Assert.Equal(HttpStatusCode.Created, (await client.PostAsJsonAsync("/api/v1/auth/register/carrier", new
        {
            fullName = "Veli Nakliyat", email, phone, password = Password, homeCityId = 33,
            vehicles = new[] { new { type = "Truck", capacityKg = 24000 } }, kvkkAccepted = true
        })).StatusCode);

    private static Task<HttpResponseMessage> LoginAsync(HttpClient client, string emailOrPhone = "ali@x.com", string password = Password) =>
        client.PostAsJsonAsync("/api/v1/auth/login", new { emailOrPhone, password, deviceId = "device-1", deviceName = "iPhone" });

    private static HttpRequestMessage Get(string url, string? token)
    {
        var request = new HttpRequestMessage(HttpMethod.Get, url);
        if (token is not null)
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return request;
    }

    // ---------- giriş ----------
    [Fact]
    public async Task Login_returns_200_with_token_expiry_and_user_summary()
    {
        var (client, _) = await StartAsync();
        await RegisterShipperAsync(client);

        var response = await LoginAsync(client);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var json = await ReadJson(response);
        Assert.False(string.IsNullOrWhiteSpace(json.GetProperty("accessToken").GetString()));
        var expires = DateTime.Parse(json.GetProperty("accessTokenExpiresAt").GetString()!, null, System.Globalization.DateTimeStyles.AdjustToUniversal);
        Assert.InRange(expires, DateTime.UtcNow.AddMinutes(14), DateTime.UtcNow.AddMinutes(16));
        var user = json.GetProperty("user");
        Assert.Equal("Ali Veli", user.GetProperty("displayName").GetString());
        Assert.Equal("Shipper", user.GetProperty("role").GetString());
        Assert.True(Guid.TryParse(user.GetProperty("id").GetString(), out _));
        Assert.Equal(["accessToken", "accessTokenExpiresAt", "user"], json.EnumerateObject().Select(p => p.Name).Order());
        Assert.DoesNotContain("passwordHash", await response.Content.ReadAsStringAsync(), StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Login_dates_follow_the_utc_iso8601_rule()
    {
        var (client, _) = await StartAsync();
        await RegisterShipperAsync(client);

        var text = (await ReadJson(await LoginAsync(client))).GetProperty("accessTokenExpiresAt").GetString()!;

        Assert.Matches(@"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", text);
    }

    [Theory]
    [InlineData("0532 123 45 67")]
    [InlineData("+905321234567")]
    [InlineData("532-123-45-67")]
    [InlineData("ALI@X.COM")]
    [InlineData("  ali@x.com  ")]
    public async Task Login_works_with_email_in_any_case_or_phone_in_any_format(string emailOrPhone)
    {
        var (client, _) = await StartAsync();
        await RegisterShipperAsync(client);

        Assert.Equal(HttpStatusCode.OK, (await LoginAsync(client, emailOrPhone)).StatusCode);
    }

    [Fact]
    public async Task A_carrier_logs_in_with_the_Carrier_role()
    {
        var (client, _) = await StartAsync();
        await RegisterCarrierAsync(client);

        var json = await ReadJson(await LoginAsync(client, "veli@x.com"));

        Assert.Equal("Carrier", json.GetProperty("user").GetProperty("role").GetString());
    }

    [Fact]
    public async Task The_issued_token_carries_only_sub_role_and_jti_and_no_personal_data()
    {
        var (client, _) = await StartAsync();
        await RegisterShipperAsync(client);
        var json = await ReadJson(await LoginAsync(client));

        var jwt = new JsonWebToken(json.GetProperty("accessToken").GetString()!);

        Assert.Equal(json.GetProperty("user").GetProperty("id").GetString(), jwt.GetClaim("sub").Value);
        Assert.Equal("Shipper", jwt.GetClaim("role").Value);
        Assert.Equal(TestJwt.Issuer, jwt.Issuer);
        Subset(["sub", "role", "jti", "iss", "aud", "exp", "iat", "nbf"], jwt.Claims.Select(c => c.Type));
        Assert.DoesNotContain(jwt.Claims, c => c.Value.Contains("ali@x.com") || c.Value.Contains("Ali Veli") || c.Value.Contains("5321234567"));
    }

    private static void Subset(string[] allowed, IEnumerable<string> actual) =>
        Assert.Empty(actual.Except(allowed));

    // ---------- hatalı giriş ----------
    [Fact]
    public async Task A_wrong_password_and_an_unknown_user_return_the_same_401()
    {
        var (client, _) = await StartAsync();
        await RegisterShipperAsync(client);

        var wrong = await LoginAsync(client, "ali@x.com", "Yanlis123");
        var unknown = await LoginAsync(client, "yok@x.com");
        var weirdIdentifier = await LoginAsync(client, "abc");

        foreach (var response in new[] { wrong, unknown, weirdIdentifier })
        {
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
            Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        }

        var a = await ReadJson(wrong);
        var b = await ReadJson(unknown);
        var c = await ReadJson(weirdIdentifier);
        Assert.Equal(401, a.GetProperty("status").GetInt32());
        Assert.Equal("Giriş başarısız", a.GetProperty("title").GetString());
        Assert.Equal("E-posta veya şifre hatalı.", a.GetProperty("detail").GetString());
        Assert.Equal(a.GetProperty("title").GetString(), b.GetProperty("title").GetString());
        Assert.Equal(a.GetProperty("detail").GetString(), b.GetProperty("detail").GetString());
        Assert.Equal(a.GetProperty("detail").GetString(), c.GetProperty("detail").GetString());
        Assert.True(a.TryGetProperty("traceId", out _));
    }

    [Fact]
    public async Task Five_wrong_attempts_return_423_with_retry_after_and_even_the_right_password_stays_refused()
    {
        var (client, _) = await StartAsync();
        await RegisterShipperAsync(client);

        for (var attempt = 1; attempt <= 4; attempt++)
            Assert.Equal(HttpStatusCode.Unauthorized, (await LoginAsync(client, "ali@x.com", "Yanlis123")).StatusCode);

        var locked = await LoginAsync(client, "ali@x.com", "Yanlis123");
        Assert.Equal(HttpStatusCode.Locked, locked.StatusCode);
        Assert.Equal("application/problem+json", locked.Content.Headers.ContentType?.MediaType);
        var problem = await ReadJson(locked);
        Assert.Equal(423, problem.GetProperty("status").GetInt32());
        Assert.Equal("Hesap geçici olarak kilitlendi", problem.GetProperty("title").GetString());
        Assert.Contains("kilitlendi", problem.GetProperty("detail").GetString());
        var retryAfter = locked.Headers.RetryAfter?.Delta;
        Assert.NotNull(retryAfter);
        Assert.InRange(retryAfter.Value, TimeSpan.FromMinutes(14), TimeSpan.FromMinutes(15));

        Assert.Equal(HttpStatusCode.Locked, (await LoginAsync(client)).StatusCode);
    }

    [Fact]
    public async Task A_blocked_user_with_the_right_password_gets_403()
    {
        var (client, db) = await StartAsync();
        await RegisterShipperAsync(client);
        await using (var context = db.NewContext())
        {
            (await context.Users.SingleAsync()).IsBlocked = true;
            await context.SaveChangesAsync();
        }

        var response = await LoginAsync(client);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        var problem = await ReadJson(response);
        Assert.Equal("Erişim engellendi", problem.GetProperty("title").GetString());
        Assert.Equal("Hesabınız şu an kullanılamıyor. Lütfen destek ile iletişime geçin.", problem.GetProperty("detail").GetString());
    }

    [Fact]
    public async Task An_empty_body_returns_400_with_turkish_messages()
    {
        var (client, _) = await StartAsync();

        var response = await client.PostAsJsonAsync("/api/v1/auth/login", new { });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var errors = (await ReadJson(response)).GetProperty("errors");
        Assert.Equal("E-posta veya telefon boş olamaz.", errors.GetProperty("emailOrPhone")[0].GetString());
        Assert.Equal("Şifre boş olamaz.", errors.GetProperty("password")[0].GetString());
        Assert.Equal("Cihaz kimliği boş olamaz.", errors.GetProperty("deviceId")[0].GetString());
    }

    // ---------- jetonla korumalı uçlar ----------
    [Fact]
    public async Task A_protected_endpoint_returns_401_without_a_token()
    {
        var (client, _) = await StartAsync();

        var response = await client.SendAsync(Get("/api/v1/test/secure", null));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
    }

    [Fact]
    public async Task A_protected_endpoint_returns_200_with_a_token_from_login_and_knows_who_and_what_role()
    {
        var (client, _) = await StartAsync();
        await RegisterShipperAsync(client);
        var login = await ReadJson(await LoginAsync(client));
        var token = login.GetProperty("accessToken").GetString();

        var response = await client.SendAsync(Get("/api/v1/test/secure", token));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var json = await ReadJson(response);
        Assert.Equal(login.GetProperty("user").GetProperty("id").GetString(), json.GetProperty("sub").GetString());
        Assert.Equal("Shipper", json.GetProperty("role").GetString());
        Assert.True(json.GetProperty("isShipper").GetBoolean());
    }

    [Fact]
    public async Task Roles_work_a_shipper_token_opens_shipper_endpoints_and_is_403_on_admin_endpoints()
    {
        var (client, _) = await StartAsync();
        await RegisterShipperAsync(client);
        var token = (await ReadJson(await LoginAsync(client))).GetProperty("accessToken").GetString();

        Assert.Equal(HttpStatusCode.OK, (await client.SendAsync(Get("/api/v1/test/shipper-only", token))).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.SendAsync(Get("/api/v1/test/admin-only", token))).StatusCode);
    }

    [Fact]
    public async Task A_carrier_token_is_403_on_shipper_endpoints()
    {
        var (client, _) = await StartAsync();
        await RegisterCarrierAsync(client);
        var token = (await ReadJson(await LoginAsync(client, "veli@x.com"))).GetProperty("accessToken").GetString();

        Assert.Equal(HttpStatusCode.Forbidden, (await client.SendAsync(Get("/api/v1/test/shipper-only", token))).StatusCode);
    }

    [Fact]
    public async Task Garbage_expired_wrongly_signed_and_wrong_audience_tokens_are_all_401()
    {
        var (client, _) = await StartAsync();

        var tokens = new[]
        {
            "bu-bir-jeton-degil",
            TestJwt.Create(notBefore: DateTime.UtcNow.AddHours(-2), expires: DateTime.UtcNow.AddHours(-1)),
            TestJwt.Create(key: "baska-bir-imza-anahtari-en-az-32-karakter-uzunlugunda!"),
            TestJwt.Create(audience: "baska-bir-hedef"),
            TestJwt.Create(issuer: "baska-bir-yayinci")
        };

        foreach (var token in tokens)
            Assert.Equal(HttpStatusCode.Unauthorized, (await client.SendAsync(Get("/api/v1/test/secure", token))).StatusCode);
    }

    [Fact]
    public async Task A_correctly_made_token_is_accepted_which_proves_the_rejections_above_are_real()
    {
        var (client, _) = await StartAsync();

        Assert.Equal(HttpStatusCode.OK, (await client.SendAsync(Get("/api/v1/test/secure", TestJwt.Create()))).StatusCode);
    }

    [Fact]
    public async Task Public_endpoints_stay_open_without_a_token()
    {
        var (client, _) = await StartAsync();

        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/v1/cities")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/health")).StatusCode);
    }

    [Fact]
    public async Task Login_appears_in_the_v1_OpenAPI_document()
    {
        var (client, _) = await StartAsync();

        var paths = (await ReadJson(await client.GetAsync("/openapi/v1.json"))).GetProperty("paths");

        Assert.True(paths.GetProperty("/api/v1/auth/login").TryGetProperty("post", out _));
    }
}
