using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Time.Testing;
using Yukum.Domain.Accounts;
using Yukum.Infrastructure.Identity;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Api;

// POST /api/v1/auth/register/shipper ve /register/carrier: gerçek API + gerçek SQL Server, uçtan uca.
[Collection("SqlServer")]
public class AuthRegisterApiTests(SqlServerFixture sql)
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 25, 9, 0, 0, TimeSpan.Zero);

    private async Task<(HttpClient Client, TestDatabase Db)> StartAsync()
    {
        var database = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));
        var client = new YukumApiFactory()
            .WithWebHostBuilder(builder => builder.UseSetting("ConnectionStrings:DefaultConnection", database.ConnectionString))
            .CreateClient();
        return (client, database);
    }

    private static async Task<JsonElement> ReadJson(HttpResponseMessage response) =>
        JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement;

    private static object ShipperBody(string email = "ali@x.com", string phone = "0532 123 45 67", string password = "Abcdefg1") => new
    {
        fullName = "Ali Veli", email, phone, password, cityId = 33,
        companyName = "Ali Tarım", taxNumber = "1234567890", taxOffice = "Mersin", kvkkAccepted = true
    };

    private static object CarrierBody(string email = "veli@x.com", string phone = "0533 222 11 00") => new
    {
        fullName = "Veli Nakliyat", email, phone, password = "Abcdefg1", homeCityId = 33, serviceCityIds = new[] { 33, 1 },
        vehicles = new object[]
        {
            new { type = "Truck", plateNumber = "33 ABC 123", capacityKg = 24000, capacityVolume = 90 },
            new { type = "Refrigerated", capacityKg = 8000 }
        },
        kvkkAccepted = true
    };

    // ---------- Yük Veren ----------
    [Fact]
    public async Task Shipper_registration_returns_201_with_a_user_summary_and_no_secrets()
    {
        var (client, db) = await StartAsync();

        var response = await client.PostAsJsonAsync("/api/v1/auth/register/shipper", ShipperBody());

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var json = await ReadJson(response);
        Assert.True(Guid.TryParse(json.GetProperty("id").GetString(), out _));
        Assert.Equal("Ali Veli", json.GetProperty("fullName").GetString());
        Assert.Equal("ali@x.com", json.GetProperty("email").GetString());
        Assert.Equal("Shipper", json.GetProperty("userType").GetString());
        Assert.Equal(["email", "fullName", "id", "userType"], json.EnumerateObject().Select(p => p.Name).Order());

        await using var context = db.NewContext();
        Assert.Equal(1, await context.Users.CountAsync(u => u.UserType == UserType.Shipper));
    }

    [Fact]
    public async Task Phone_is_stored_in_plus90_format_and_email_in_lower_case()
    {
        var (client, db) = await StartAsync();

        var response = await client.PostAsJsonAsync("/api/v1/auth/register/shipper", ShipperBody("ALI@X.COM", "0532 123 45 67"));

        Assert.Equal("ali@x.com", (await ReadJson(response)).GetProperty("email").GetString());
        await using var context = db.NewContext();
        var user = await context.Users.SingleAsync();
        Assert.Equal("+905321234567", user.PhoneNumber);
        Assert.Equal("ali@x.com", user.Email);
    }

    [Fact]
    public async Task The_client_cannot_choose_a_role_the_endpoint_decides()
    {
        var (client, db) = await StartAsync();
        var body = new { fullName = "Kötü Niyetli", email = "k@x.com", phone = "0532 000 00 01", password = "Abcdefg1", cityId = 33, kvkkAccepted = true, userType = "Admin", role = "Admin" };

        var response = await client.PostAsJsonAsync("/api/v1/auth/register/shipper", body);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.Equal("Shipper", (await ReadJson(response)).GetProperty("userType").GetString());
        await using var context = db.NewContext();
        Assert.Equal(UserType.Shipper, (await context.Users.SingleAsync()).UserType);
        Assert.Equal(0, await context.UserRoles.CountAsync(r => r.RoleId == Yukum.Infrastructure.Persistence.Seed.RoleSeed.AdminId));
    }

    [Fact]
    public async Task An_empty_body_returns_400_with_turkish_messages_for_every_required_field()
    {
        var (client, _) = await StartAsync();

        var response = await client.PostAsJsonAsync("/api/v1/auth/register/shipper", new { });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        var problem = await ReadJson(response);
        Assert.Equal("Doğrulama hatası", problem.GetProperty("title").GetString());
        Assert.Equal(400, problem.GetProperty("status").GetInt32());
        var errors = problem.GetProperty("errors");
        Assert.Equal("Ad soyad boş olamaz.", errors.GetProperty("fullName")[0].GetString());
        Assert.Equal("E-posta boş olamaz.", errors.GetProperty("email")[0].GetString());
        Assert.Equal("Telefon numarası boş olamaz.", errors.GetProperty("phone")[0].GetString());
        Assert.Equal("Şifre boş olamaz.", errors.GetProperty("password")[0].GetString());
        Assert.Equal("İl seçin.", errors.GetProperty("cityId")[0].GetString());
        Assert.Equal("Devam etmek için KVKK aydınlatma metnini onaylamanız gerekir.", errors.GetProperty("kvkkAccepted")[0].GetString());
    }

    [Fact]
    public async Task A_weak_password_returns_400_pointing_at_the_password_field()
    {
        var (client, db) = await StartAsync();

        var response = await client.PostAsJsonAsync("/api/v1/auth/register/shipper", ShipperBody(password: "abcdefg1"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var errors = (await ReadJson(response)).GetProperty("errors");
        Assert.Equal("Şifre en az bir büyük harf içermeli.", errors.GetProperty("password")[0].GetString());
        await using var context = db.NewContext();
        Assert.Equal(0, await context.Users.CountAsync());
    }

    [Fact]
    public async Task A_malformed_enum_value_is_a_400_not_a_server_error()
    {
        var (client, _) = await StartAsync();
        var body = new { fullName = "Veli", email = "v@x.com", phone = "0533 222 11 00", password = "Abcdefg1", homeCityId = 33, vehicles = new[] { new { type = "Roket", capacityKg = 100 } }, kvkkAccepted = true };

        var response = await client.PostAsJsonAsync("/api/v1/auth/register/carrier", body);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task The_same_email_twice_returns_409_with_a_clear_message()
    {
        var (client, db) = await StartAsync();
        await client.PostAsJsonAsync("/api/v1/auth/register/shipper", ShipperBody("ali@x.com", "0532 123 45 67"));

        var response = await client.PostAsJsonAsync("/api/v1/auth/register/shipper", ShipperBody("ALI@x.com", "0532 999 99 99"));

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        var problem = await ReadJson(response);
        Assert.Equal(409, problem.GetProperty("status").GetInt32());
        Assert.Equal("Çakışma", problem.GetProperty("title").GetString());
        Assert.Equal("Bu e-posta adresiyle zaten bir hesap var.", problem.GetProperty("detail").GetString());
        Assert.True(problem.TryGetProperty("traceId", out _));
        await using var context = db.NewContext();
        Assert.Equal(1, await context.Users.CountAsync());
    }

    [Fact]
    public async Task The_same_phone_written_differently_returns_409()
    {
        var (client, _) = await StartAsync();
        await client.PostAsJsonAsync("/api/v1/auth/register/shipper", ShipperBody("ali@x.com", "0532 123 45 67"));

        var response = await client.PostAsJsonAsync("/api/v1/auth/register/shipper", ShipperBody("baska@x.com", "+90 (532) 123-45-67"));

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal("Bu telefon numarasıyla zaten bir hesap var.", (await ReadJson(response)).GetProperty("detail").GetString());
    }

    [Fact]
    public async Task A_carrier_cannot_reuse_a_shippers_email()
    {
        var (client, _) = await StartAsync();
        await client.PostAsJsonAsync("/api/v1/auth/register/shipper", ShipperBody("ayni@x.com", "0532 123 45 67"));

        var response = await client.PostAsJsonAsync("/api/v1/auth/register/carrier", CarrierBody("ayni@x.com", "0533 222 11 00"));

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    // ---------- Taşımacı ----------
    [Fact]
    public async Task Carrier_registration_returns_201_and_saves_vehicles_and_service_cities()
    {
        var (client, db) = await StartAsync();

        var response = await client.PostAsJsonAsync("/api/v1/auth/register/carrier", CarrierBody());

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.Equal("Carrier", (await ReadJson(response)).GetProperty("userType").GetString());
        await using var context = db.NewContext();
        var profile = await context.CarrierProfiles.Include(p => p.Vehicles).Include(p => p.ServiceCities).SingleAsync();
        Assert.Equal(2, profile.Vehicles.Count);
        Assert.Contains(profile.Vehicles, v => v.Type == VehicleType.Truck && v.CapacityKg == 24000);
        Assert.Contains(profile.Vehicles, v => v.Type == VehicleType.Refrigerated);
        Assert.Equal([1, 33], profile.ServiceCities.Select(c => c.CityId).Order());
        Assert.Equal(1, await context.UserRoles.CountAsync(r => r.RoleId == Yukum.Infrastructure.Persistence.Seed.RoleSeed.CarrierId));
    }

    [Fact]
    public async Task A_carrier_without_a_vehicle_returns_400()
    {
        var (client, db) = await StartAsync();
        var body = new { fullName = "Veli", email = "v@x.com", phone = "0533 222 11 00", password = "Abcdefg1", homeCityId = 33, vehicles = Array.Empty<object>(), kvkkAccepted = true };

        var response = await client.PostAsJsonAsync("/api/v1/auth/register/carrier", body);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var errors = (await ReadJson(response)).GetProperty("errors");
        Assert.Equal("En az bir araç eklemelisiniz.", errors.GetProperty("vehicles")[0].GetString());
        await using var context = db.NewContext();
        Assert.Equal(0, await context.Users.CountAsync());
    }

    [Fact]
    public async Task A_vehicle_error_names_the_exact_field_in_camelCase()
    {
        var (client, _) = await StartAsync();
        var body = new { fullName = "Veli", email = "v@x.com", phone = "0533 222 11 00", password = "Abcdefg1", homeCityId = 33, vehicles = new[] { new { type = "Truck", capacityKg = 100 }, new { type = "Truck", capacityKg = 0 } }, kvkkAccepted = true };

        var response = await client.PostAsJsonAsync("/api/v1/auth/register/carrier", body);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var errors = (await ReadJson(response)).GetProperty("errors");
        Assert.Equal("Taşıma kapasitesi 0'dan büyük olmalı.", errors.GetProperty("vehicles[1].capacityKg")[0].GetString());
        Assert.False(errors.TryGetProperty("vehicles[0].capacityKg", out _));
    }

    [Fact]
    public async Task Both_register_endpoints_appear_in_the_v1_OpenAPI_document_as_anonymous_posts()
    {
        var (client, _) = await StartAsync();

        var paths = (await ReadJson(await client.GetAsync("/openapi/v1.json"))).GetProperty("paths");

        Assert.True(paths.GetProperty("/api/v1/auth/register/shipper").TryGetProperty("post", out _));
        Assert.True(paths.GetProperty("/api/v1/auth/register/carrier").TryGetProperty("post", out _));
    }
}
