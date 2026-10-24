using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Api;

public class ApiConventionTests(YukumApiFactory factory) : IClassFixture<YukumApiFactory>
{
    private readonly HttpClient _client = factory.CreateClient();

    private static async Task<JsonElement> ReadJson(HttpResponseMessage response) =>
        JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement;

    // ---------- JSON kuralları (iOS Codable ile uyum) ----------
    [Fact]
    public async Task Json_property_names_are_camelCase()
    {
        var json = await ReadJson(await _client.GetAsync("/api/v1/test/sample"));
        Assert.True(json.TryGetProperty("userName", out _));
        Assert.True(json.TryGetProperty("currentStatus", out _));
        Assert.False(json.TryGetProperty("UserName", out _));
    }

    [Fact]
    public async Task Json_enums_are_strings()
    {
        var json = await ReadJson(await _client.GetAsync("/api/v1/test/sample"));
        Assert.Equal(JsonValueKind.String, json.GetProperty("currentStatus").ValueKind);
        Assert.Equal("InTransit", json.GetProperty("currentStatus").GetString());
    }

    [Fact]
    public async Task Json_dates_are_utc_iso8601_without_fractional_seconds()
    {
        var json = await ReadJson(await _client.GetAsync("/api/v1/test/sample"));
        // 10:15:00.987 +03:00  ->  07:15:00Z  (Swift .iso8601 kesirli saniyeyi okuyamaz)
        Assert.Equal("2026-10-20T07:15:00Z", json.GetProperty("createdAt").GetString());
        Assert.Equal("2026-10-20T07:15:00Z", json.GetProperty("updatedAt").GetString());
    }

    [Fact]
    public async Task Json_dates_are_read_from_any_iso8601_offset_and_returned_as_utc()
    {
        var response = await _client.PostAsJsonAsync("/api/v1/test/echo-date", new { when = "2026-10-20T10:15:00+03:00" });
        Assert.Equal("2026-10-20T07:15:00Z", (await ReadJson(response)).GetString());
    }

    [Fact]
    public async Task Json_date_without_offset_is_treated_as_utc()
    {
        var response = await _client.PostAsJsonAsync("/api/v1/test/echo-date", new { when = "2026-10-20T10:15:00" });
        Assert.Equal("2026-10-20T10:15:00Z", (await ReadJson(response)).GetString());
    }

    [Fact]
    public async Task Json_invalid_date_returns_400_problem()
    {
        var response = await _client.PostAsJsonAsync("/api/v1/test/echo-date", new { when = "yarin-sabah" });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
    }

    [Fact]
    public async Task Json_money_is_number_and_guid_is_string()
    {
        var json = await ReadJson(await _client.GetAsync("/api/v1/test/sample"));
        Assert.Equal(JsonValueKind.Number, json.GetProperty("price").ValueKind);
        Assert.Equal(1250.50m, json.GetProperty("price").GetDecimal());
        Assert.Equal("11111111-2222-3333-4444-555555555555", json.GetProperty("id").GetString());
    }

    // ---------- Hata formatı (ProblemDetails) ----------
    [Fact]
    public async Task Unhandled_exception_returns_500_problem_without_internal_detail()
    {
        var response = await _client.GetAsync("/api/v1/test/boom");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        Assert.Contains("traceId", body);
        Assert.DoesNotContain("GIZLI-IC-DETAY", body);
        Assert.DoesNotContain("PasswordHash", body);
    }

    [Fact]
    public async Task Validation_error_returns_400_problem_with_camelCase_field_names()
    {
        var response = await _client.PostAsJsonAsync("/api/v1/test/validate", new { email = "abc" });
        var json = await ReadJson(response);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        Assert.True(json.GetProperty("errors").TryGetProperty("email", out _));
        Assert.False(json.GetProperty("errors").TryGetProperty("Email", out _));
        Assert.True(json.TryGetProperty("traceId", out _));
        Assert.Equal("Doğrulama hatası", json.GetProperty("title").GetString());
    }

    [Fact]
    public async Task Unknown_route_returns_404_problem()
    {
        var response = await _client.GetAsync("/api/v1/yok-boyle-bir-uc");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
    }

    // ---------- Sürümleme ----------
    [Fact]
    public async Task Versioned_route_v1_works()
    {
        var response = await _client.GetAsync("/api/v1/test/sample");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Unsupported_version_v2_is_rejected_with_404_problem()
    {
        // Sürüm adresin parçası olduğu için olmayan sürüm = olmayan adres.
        var response = await _client.GetAsync("/api/v2/test/sample");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
    }

    [Fact]
    public async Task Unversioned_route_is_not_found()
    {
        var response = await _client.GetAsync("/api/test/sample");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task OpenApi_document_lists_versioned_path_without_version_placeholder()
    {
        var text = await _client.GetStringAsync("/openapi/v1.json");
        Assert.Contains("/api/v1/test/sample", text);
        Assert.DoesNotContain("{version}", text);
    }
}
