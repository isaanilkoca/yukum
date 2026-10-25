using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Time.Testing;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Api;

// GET /api/v1/cities ve GET /api/v1/cities/{cityId}/districts: gerçek API + gerçek SQL Server, uçtan uca.
[Collection("SqlServer")]
public class CitiesApiTests(SqlServerFixture sql)
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 25, 9, 0, 0, TimeSpan.Zero);

    private async Task<HttpClient> ClientAsync()
    {
        var database = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));
        return new YukumApiFactory()
            .WithWebHostBuilder(builder => builder.UseSetting("ConnectionStrings:DefaultConnection", database.ConnectionString))
            .CreateClient();
    }

    private static async Task<JsonElement> ReadJson(HttpResponseMessage response) =>
        JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement;

    [Fact]
    public async Task Cities_returns_81_cities_anonymously_ordered_by_plate()
    {
        var client = await ClientAsync();   // oturum/jeton göndermiyoruz: uç anonimdir

        var response = await client.GetAsync("/api/v1/cities");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var json = await ReadJson(response);
        Assert.Equal(81, json.GetArrayLength());
        Assert.Equal(1, json[0].GetProperty("id").GetInt32());
        Assert.Equal("Adana", json[0].GetProperty("name").GetString());
        Assert.Equal(42, json[41].GetProperty("id").GetInt32());
        Assert.Equal("Konya", json[41].GetProperty("name").GetString());
    }

    [Fact]
    public async Task City_items_contain_only_id_and_name()
    {
        var client = await ClientAsync();

        var json = await ReadJson(await client.GetAsync("/api/v1/cities"));

        Assert.Equal(["id", "name"], json[0].EnumerateObject().Select(p => p.Name).Order());
    }

    [Fact]
    public async Task Cities_response_is_cacheable_by_clients_for_a_day()
    {
        var client = await ClientAsync();

        var response = await client.GetAsync("/api/v1/cities");

        var cacheControl = response.Headers.CacheControl;
        Assert.NotNull(cacheControl);
        Assert.True(cacheControl.Public);
        Assert.Equal(TimeSpan.FromDays(1), cacheControl.MaxAge);
    }

    [Fact]
    public async Task Districts_of_Konya_match_the_seed_file_in_order()
    {
        var client = await ClientAsync();

        var response = await client.GetAsync("/api/v1/cities/42/districts");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var json = await ReadJson(response);
        var expected = GeographySeedFile.Cities.Single(c => c.Plate == 42).Districts.Select(d => d.Name).ToList();
        Assert.Equal(expected, json.EnumerateArray().Select(d => d.GetProperty("name").GetString()!).ToList());
        Assert.Equal(["id", "name"], json[0].EnumerateObject().Select(p => p.Name).Order());
    }

    [Fact]
    public async Task Districts_of_Adana_have_ids_1_to_15()
    {
        var client = await ClientAsync();

        var json = await ReadJson(await client.GetAsync("/api/v1/cities/1/districts"));

        Assert.Equal(Enumerable.Range(1, 15), json.EnumerateArray().Select(d => d.GetProperty("id").GetInt32()));
        Assert.Equal("Aladağ", json[0].GetProperty("name").GetString());
    }

    [Fact]
    public async Task Districts_response_is_cacheable_by_clients_for_a_day()
    {
        var client = await ClientAsync();

        var response = await client.GetAsync("/api/v1/cities/42/districts");

        Assert.True(response.Headers.CacheControl?.Public);
        Assert.Equal(TimeSpan.FromDays(1), response.Headers.CacheControl?.MaxAge);
    }

    [Theory]
    [InlineData(999)]
    [InlineData(0)]
    [InlineData(82)]
    [InlineData(-1)]
    public async Task Districts_of_a_missing_city_return_404_problem_with_a_clear_message(int cityId)
    {
        var client = await ClientAsync();

        var response = await client.GetAsync($"/api/v1/cities/{cityId}/districts");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        var problem = await ReadJson(response);
        Assert.Equal(404, problem.GetProperty("status").GetInt32());
        Assert.Equal("Bulunamadı", problem.GetProperty("title").GetString());
        Assert.Equal("İl bulunamadı.", problem.GetProperty("detail").GetString());
        Assert.True(problem.TryGetProperty("traceId", out _));
    }

    [Fact]
    public async Task A_404_is_never_cached_by_clients()
    {
        var client = await ClientAsync();

        var response = await client.GetAsync("/api/v1/cities/999/districts");

        Assert.False(response.Headers.CacheControl?.Public ?? false);
        Assert.Null(response.Headers.CacheControl?.MaxAge);
    }

    [Fact]
    public async Task A_non_numeric_city_id_is_a_404_not_a_server_error()
    {
        var client = await ClientAsync();

        var response = await client.GetAsync("/api/v1/cities/abc/districts");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Both_endpoints_appear_in_the_v1_OpenAPI_document()
    {
        var client = await ClientAsync();

        var response = await client.GetAsync("/openapi/v1.json");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var paths = (await ReadJson(response)).GetProperty("paths");
        Assert.True(paths.TryGetProperty("/api/v1/cities", out _));
        Assert.True(paths.TryGetProperty("/api/v1/cities/{cityId}/districts", out _));
    }
}
