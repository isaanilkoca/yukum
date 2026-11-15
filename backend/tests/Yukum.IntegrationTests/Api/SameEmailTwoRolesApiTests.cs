using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Time.Testing;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Api;

// K-022: aynı e-posta ve telefonla bir Yük Veren + bir Taşımacı hesabı açılabilir; aynı role ikinci hesap açılamaz.
// İki hesap tamamen ayrıdır (şifre, kilit, oturum, veri). Giriş hangi hesaba gireceğini "role" alanıyla öğrenir.
[Collection("SqlServer")]
public class SameEmailTwoRolesApiTests(SqlServerFixture sql)
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 25, 9, 0, 0, TimeSpan.Zero);
    private const string Email = "ayni@x.com";
    private const string Phone = "05321112233";

    private async Task<HttpClient> StartAsync()
    {
        var database = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));
        return new YukumApiFactory()
            .WithWebHostBuilder(b => b.UseSetting("ConnectionStrings:DefaultConnection", database.ConnectionString))
            .CreateClient();
    }

    private static Task<HttpResponseMessage> RegisterShipper(HttpClient c, string password = "Abcdefg1", string email = Email, string phone = Phone) =>
        c.PostAsJsonAsync("/api/v1/auth/register/shipper", new { fullName = "Yuk Veren", email, phone, password, kvkkAccepted = true, termsAccepted = true });

    private static Task<HttpResponseMessage> RegisterCarrier(HttpClient c, string password = "Abcdefg1", string email = Email, string phone = Phone) =>
        c.PostAsJsonAsync("/api/v1/auth/register/carrier", new
        {
            fullName = "Tasimaci", email, phone, password, kvkkAccepted = true, termsAccepted = true,
            vehicles = new object[] { new { type = "Truck", capacityKg = 1000 } }
        });

    private static Task<HttpResponseMessage> Login(HttpClient c, string password, string? role, string emailOrPhone = Email) =>
        c.PostAsJsonAsync("/api/v1/auth/login", new { emailOrPhone, password, deviceId = "dev", deviceName = "t", role });

    private static async Task<JsonElement> Json(HttpResponseMessage r) => JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement;

    [Fact]
    public async Task The_same_email_and_phone_can_register_once_as_shipper_and_once_as_carrier_but_not_twice_in_one_role()
    {
        var c = await StartAsync();

        Assert.Equal(HttpStatusCode.Created, (await RegisterShipper(c)).StatusCode);
        Assert.Equal(HttpStatusCode.Created, (await RegisterCarrier(c)).StatusCode);               // aynı e-posta + telefon, diğer rol: serbest

        var shipperAgain = await RegisterShipper(c);                                                // aynı rol: 409
        var carrierAgain = await RegisterCarrier(c);
        var shipperPhoneOnly = await RegisterShipper(c, email: "baska@x.com");                      // aynı rolde yalnız telefon aynı: 409
        var upperCase = await RegisterShipper(c, email: "AYNI@X.COM", phone: "05329998877");        // büyük/küçük harf farkı aynı e-postadır: 409

        Assert.Equal(HttpStatusCode.Conflict, shipperAgain.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, carrierAgain.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, shipperPhoneOnly.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, upperCase.StatusCode);
    }

    [Fact]
    public async Task Login_picks_the_account_by_role_and_the_two_accounts_have_separate_passwords()
    {
        var c = await StartAsync();
        await RegisterShipper(c, password: "Abcdefg1");
        await RegisterCarrier(c, password: "Zxcvbnm2");

        var asShipper = await Json(await Login(c, "Abcdefg1", "Shipper"));
        var asCarrier = await Json(await Login(c, "Zxcvbnm2", "Carrier"));
        var wrongPair1 = await Login(c, "Zxcvbnm2", "Shipper");                                     // Taşımacı şifresi Yük Veren hesabında geçmez
        var wrongPair2 = await Login(c, "Abcdefg1", "Carrier");
        var byPhone = await Json(await Login(c, "Zxcvbnm2", "carrier", Phone));                     // telefonla da, rol büyük/küçük harf fark etmez

        Assert.Equal("Shipper", asShipper.GetProperty("user").GetProperty("role").GetString());
        Assert.Equal("Carrier", asCarrier.GetProperty("user").GetProperty("role").GetString());
        Assert.Equal(HttpStatusCode.Unauthorized, wrongPair1.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, wrongPair2.StatusCode);
        Assert.Equal("Carrier", byPhone.GetProperty("user").GetProperty("role").GetString());
    }

    [Fact]
    public async Task Without_a_role_login_works_for_a_single_account_and_asks_for_the_role_when_there_are_two()
    {
        var c = await StartAsync();
        await RegisterShipper(c);
        var single = await Login(c, "Abcdefg1", role: null);                                        // tek hesap: rol gerekmez

        await RegisterCarrier(c);
        var ambiguous = await Login(c, "Abcdefg1", role: null);                                     // iki hesap: rol seçilmeli
        var invalidRole = await Login(c, "Abcdefg1", role: "Admin");                                // Admin ile giriş bu uçtan yapılmaz

        Assert.Equal(HttpStatusCode.OK, single.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, ambiguous.StatusCode);
        Assert.Contains("hesabı", await ambiguous.Content.ReadAsStringAsync());
        Assert.Equal(HttpStatusCode.BadRequest, invalidRole.StatusCode);
    }

    [Fact]
    public async Task Lockout_and_deletion_affect_only_the_account_of_that_role()
    {
        var c = await StartAsync();
        await RegisterShipper(c);
        await RegisterCarrier(c);

        for (var i = 0; i < 10; i++) await Login(c, "Yanlis123", "Shipper");                       // Yük Veren hesabı kilitlenir
        var shipperLocked = await Login(c, "Abcdefg1", "Shipper");
        var carrierStillOk = await Login(c, "Abcdefg1", "Carrier");                                 // Taşımacı hesabı etkilenmez

        var token = (await Json(carrierStillOk)).GetProperty("accessToken").GetString()!;
        var delete = new HttpRequestMessage(HttpMethod.Post, "/api/v1/account/delete") { Content = JsonContent.Create(new { password = "Abcdefg1" }) };
        delete.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var deleted = await c.SendAsync(delete);                                                    // Taşımacı hesabı silinir
        var carrierGone = await Login(c, "Abcdefg1", "Carrier");
        var carrierReRegister = await RegisterCarrier(c);                                           // aynı e-posta Taşımacı olarak yeniden alınabilir

        Assert.Equal(HttpStatusCode.Locked, shipperLocked.StatusCode);
        Assert.Equal(HttpStatusCode.OK, carrierStillOk.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, carrierGone.StatusCode);
        Assert.Equal(HttpStatusCode.Created, carrierReRegister.StatusCode);
    }
}
