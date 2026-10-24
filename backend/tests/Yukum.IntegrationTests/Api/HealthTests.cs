using System.Net;
using Microsoft.AspNetCore.Hosting;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Api;

[Collection("SqlServer")]
public class HealthTests(SqlServerFixture sql)
{
    private static HttpClient ClientWith(string connectionString) =>
        new YukumApiFactory()
            .WithWebHostBuilder(builder => builder.UseSetting("ConnectionStrings:DefaultConnection", connectionString))
            .CreateClient();

    [Fact]
    public async Task Health_is_200_Healthy_when_database_is_reachable()
    {
        var database = await sql.CreateDatabaseAsync(TimeProvider.System);

        var response = await ClientWith(database.ConnectionString).GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("Healthy", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Health_is_503_Unhealthy_when_database_is_unreachable()
    {
        // 1 numaralı port kapalı: bağlantı hemen reddedilir.
        const string unreachable = "Server=localhost,1;Database=yok;User Id=sa;Password=x;TrustServerCertificate=True;Connect Timeout=3";

        var response = await ClientWith(unreachable).GetAsync("/health");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal("Unhealthy", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Health_is_503_Unhealthy_when_connection_string_is_missing()
    {
        var response = await new YukumApiFactory().CreateClient().GetAsync("/health");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }
}
