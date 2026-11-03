using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Time.Testing;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Api;

// Yenileme jetonu: rotasyon, çalıntı (reuse) tespiti, cihaz bağlama, çıkış, DB'de yalnız hash, hız sınırı. Gerçek API + gerçek SQL Server.
[Collection("SqlServer")]
public class AuthRefreshApiTests(SqlServerFixture sql)
{
    private const string Password = "Abcdefg1";

    private async Task<(HttpClient Client, TestDatabase Db)> StartAsync(Action<IWebHostBuilder>? configure = null)
    {
        var database = await sql.CreateDatabaseAsync(new FakeTimeProvider());
        var client = new YukumApiFactory().WithWebHostBuilder(builder =>
        {
            builder.UseSetting("ConnectionStrings:DefaultConnection", database.ConnectionString);
            configure?.Invoke(builder);
        }).CreateClient();
        return (client, database);
    }

    private static async Task<JsonElement> Json(HttpResponseMessage r) => JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement;

    private static async Task<JsonElement> LoginAsync(HttpClient c, string device = "device-1")
    {
        await c.PostAsJsonAsync("/api/v1/auth/register/shipper", new
        {
            fullName = "Ali Veli", email = "ali@x.com", phone = "0532 123 45 67", password = Password, cityId = 33, kvkkAccepted = true
        });   // ikinci girişte 409 döner, önemli değil
        var login = await c.PostAsJsonAsync("/api/v1/auth/login", new { emailOrPhone = "ali@x.com", password = Password, deviceId = device, deviceName = "iPhone" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        return await Json(login);
    }

    private static Task<HttpResponseMessage> Refresh(HttpClient c, string token, string device = "device-1") =>
        c.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = token, deviceId = device });

    [Fact]
    public async Task Login_returns_a_refresh_token_and_only_its_hash_is_stored()
    {
        var (c, db) = await StartAsync();

        var login = await LoginAsync(c);
        var raw = login.GetProperty("refreshToken").GetString()!;

        Assert.True(raw.Length >= 40);
        await using var context = db.NewContext();
        var row = await context.RefreshTokens.SingleAsync();
        Assert.NotEqual(raw, row.TokenHash);                  // düz jeton saklanmaz
        Assert.Equal(64, row.TokenHash.Length);               // SHA-256 onaltılık özeti
        Assert.DoesNotContain(raw, row.TokenHash);
    }

    [Fact]
    public async Task Refresh_rotates_the_token_and_returns_a_working_access_token()
    {
        var (c, _) = await StartAsync();
        var login = await LoginAsync(c);
        var oldRefresh = login.GetProperty("refreshToken").GetString()!;

        var response = await Refresh(c, oldRefresh);
        var body = await Json(response);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotEqual(oldRefresh, body.GetProperty("refreshToken").GetString());     // yeni jeton
        Assert.False(string.IsNullOrWhiteSpace(body.GetProperty("accessToken").GetString()));
        Assert.Equal("Shipper", body.GetProperty("user").GetProperty("role").GetString());
        // yeni erişim jetonu gerçekten çalışıyor
        var request = new HttpRequestMessage(HttpMethod.Get, "/api/v1/listings/mine");
        request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", body.GetProperty("accessToken").GetString());
        Assert.Equal(HttpStatusCode.OK, (await c.SendAsync(request)).StatusCode);
    }

    [Fact]
    public async Task Reusing_an_old_refresh_token_is_treated_as_theft_and_revokes_the_whole_family()
    {
        var (c, _) = await StartAsync();
        var oldRefresh = (await LoginAsync(c)).GetProperty("refreshToken").GetString()!;
        var rotated = await Json(await Refresh(c, oldRefresh));                    // normal kullanım: eskisi iptal oldu
        var newRefresh = rotated.GetProperty("refreshToken").GetString()!;

        var reuse = await Refresh(c, oldRefresh);                                  // iptal edilmiş jeton tekrar geldi (çalıntı)
        var afterTheft = await Refresh(c, newRefresh);                             // meşru yeni jeton da artık geçersiz

        Assert.Equal(HttpStatusCode.Unauthorized, reuse.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, afterTheft.StatusCode);          // tüm aile iptal edildi
    }

    [Fact]
    public async Task Refresh_token_is_bound_to_its_device()
    {
        var (c, _) = await StartAsync();
        var refresh = (await LoginAsync(c, "device-1")).GetProperty("refreshToken").GetString()!;

        var otherDevice = await Refresh(c, refresh, "baska-cihaz");

        Assert.Equal(HttpStatusCode.Unauthorized, otherDevice.StatusCode);
    }

    [Fact]
    public async Task Logout_revokes_the_token_and_is_always_successful()
    {
        var (c, _) = await StartAsync();
        var refresh = (await LoginAsync(c)).GetProperty("refreshToken").GetString()!;

        var logout = await c.PostAsJsonAsync("/api/v1/auth/logout", new { refreshToken = refresh });
        var afterLogout = await Refresh(c, refresh);
        var unknown = await c.PostAsJsonAsync("/api/v1/auth/logout", new { refreshToken = "bilinmeyen" });   // bilgi sızdırılmaz

        Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, afterLogout.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, unknown.StatusCode);
    }

    [Fact]
    public async Task A_new_login_on_the_same_device_replaces_the_previous_session()
    {
        var (c, _) = await StartAsync();
        var first = (await LoginAsync(c, "device-1")).GetProperty("refreshToken").GetString()!;
        var second = (await LoginAsync(c, "device-1")).GetProperty("refreshToken").GetString()!;

        Assert.Equal(HttpStatusCode.Unauthorized, (await Refresh(c, first)).StatusCode);   // cihaz başına tek oturum
        Assert.Equal(HttpStatusCode.OK, (await Refresh(c, second)).StatusCode);
    }

    [Fact]
    public async Task Unknown_or_missing_tokens_are_rejected()
    {
        var (c, _) = await StartAsync();

        Assert.Equal(HttpStatusCode.Unauthorized, (await Refresh(c, "uydurma-jeton")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await c.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = "", deviceId = "d" })).StatusCode);
    }

    [Fact]
    public async Task Auth_endpoints_are_rate_limited_per_minute()
    {
        var (c, _) = await StartAsync(builder => builder.UseSetting("RateLimiting:AuthPerMinute", "3"));

        var codes = new List<HttpStatusCode>();
        for (var i = 0; i < 5; i++)
            codes.Add((await Refresh(c, "x")).StatusCode);

        Assert.Equal(HttpStatusCode.Unauthorized, codes[0]);   // ilk 3 istek işlenir (jeton yanlış → 401)
        Assert.Equal(HttpStatusCode.Unauthorized, codes[2]);
        Assert.Equal(HttpStatusCode.TooManyRequests, codes[3]);   // sınır aşıldı → 429
        Assert.Equal(HttpStatusCode.TooManyRequests, codes[4]);
    }
}
