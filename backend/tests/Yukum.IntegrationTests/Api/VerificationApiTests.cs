using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Time.Testing;
using Yukum.Application.Abstractions.Identity;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Api;

// E-posta doğrulama + şifremi unuttum (15 Kasım): gerçek API + gerçek SQL Server; e-postalar CapturingEmailSender'a düşer.
// Bu sınıfta doğrulama ZORUNLU (Auth:RequireVerifiedEmail=true), diğer testlerde kapalı.
[Collection("SqlServer")]
public class VerificationApiTests(SqlServerFixture sql)
{
    private const string Email = "ayse@x.com";

    private async Task<(HttpClient Client, CapturingEmailSender Mail)> StartAsync()
    {
        var database = await sql.CreateDatabaseAsync(new FakeTimeProvider(new DateTimeOffset(2026, 11, 15, 9, 0, 0, TimeSpan.Zero)));
        var mail = new CapturingEmailSender();
        var client = new YukumApiFactory().WithWebHostBuilder(b =>
        {
            b.UseSetting("ConnectionStrings:DefaultConnection", database.ConnectionString);
            b.UseSetting("Auth:RequireVerifiedEmail", "true");
            b.ConfigureTestServices(s => { s.RemoveAll<IEmailSender>(); s.AddSingleton<IEmailSender>(mail); });
        }).CreateClient();
        return (client, mail);
    }

    private static Task<HttpResponseMessage> Register(HttpClient c) => c.PostAsJsonAsync("/api/v1/auth/register/shipper",
        new { fullName = "Ayşe Kaya", email = Email, phone = "0532 111 22 33", password = "Abcdefg1", kvkkAccepted = true, termsAccepted = true });

    private static Task<HttpResponseMessage> Login(HttpClient c, string password = "Abcdefg1") =>
        c.PostAsJsonAsync("/api/v1/auth/login", new { emailOrPhone = Email, password, role = "Shipper", deviceId = "d1", deviceName = "t" });

    private static async Task<JsonElement> Json(HttpResponseMessage r) => JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement;

    [Fact]
    public async Task Registration_sends_a_code_login_is_blocked_until_the_code_is_entered()
    {
        var (c, mail) = await StartAsync();
        Assert.Equal(HttpStatusCode.Created, (await Register(c)).StatusCode);
        var code = mail.LastCode(Email);

        var before = await Login(c);
        var wrongPassword = await Login(c, "Yanlis123");
        var wrongCode = await c.PostAsJsonAsync("/api/v1/auth/verify-email", new { emailOrPhone = Email, role = "Shipper", code = code == "000000" ? "111111" : "000000" });
        var verify = await c.PostAsJsonAsync("/api/v1/auth/verify-email", new { emailOrPhone = Email, role = "Shipper", code });
        var again = await c.PostAsJsonAsync("/api/v1/auth/verify-email", new { emailOrPhone = Email, role = "Shipper", code });
        var after = await Login(c);

        Assert.Single(mail.Sent);
        Assert.Matches(@"^\d{6}$", code);
        Assert.Equal(HttpStatusCode.Forbidden, before.StatusCode);
        Assert.Equal("email_not_verified", (await Json(before)).GetProperty("code").GetString()); // iOS kod ekranını bundan anlar
        Assert.Equal(HttpStatusCode.Unauthorized, wrongPassword.StatusCode);                        // şifre yanlışsa hesap durumu sızmaz
        Assert.Equal(HttpStatusCode.BadRequest, wrongCode.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, verify.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, again.StatusCode);                                   // tekrar basmak zarar vermez
        Assert.Equal(HttpStatusCode.OK, after.StatusCode);
    }

    [Fact]
    public async Task Sending_does_not_reveal_whether_an_email_exists_and_resend_has_a_cooldown()
    {
        var (c, mail) = await StartAsync();
        await Register(c);

        var unknown = await c.PostAsJsonAsync("/api/v1/auth/password/forgot", new { emailOrPhone = "yok@x.com", role = "Shipper" });
        var otherRole = await c.PostAsJsonAsync("/api/v1/auth/password/forgot", new { emailOrPhone = Email, role = "Carrier" });
        var resendTooSoon = await c.PostAsJsonAsync("/api/v1/auth/verify-email/send", new { emailOrPhone = Email, role = "Shipper" });
        var badRole = await c.PostAsJsonAsync("/api/v1/auth/password/forgot", new { emailOrPhone = Email, role = "Admin" });

        Assert.Equal(HttpStatusCode.NoContent, unknown.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, otherRole.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, resendTooSoon.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, badRole.StatusCode);
        Assert.Single(mail.Sent); // yalnız kayıttaki kod: olmayan hesaba gitmez, 60 sn dolmadan yenisi gitmez
    }

    [Fact]
    public async Task Password_reset_changes_the_password_verifies_the_email_and_ends_all_sessions()
    {
        var (c, mail) = await StartAsync();
        await Register(c);
        await c.PostAsJsonAsync("/api/v1/auth/verify-email", new { emailOrPhone = Email, role = "Shipper", code = mail.LastCode(Email) });
        var session = await Json(await Login(c));

        await c.PostAsJsonAsync("/api/v1/auth/password/forgot", new { emailOrPhone = Email, role = "Shipper" });
        var code = mail.LastCode(Email);
        var weak = await c.PostAsJsonAsync("/api/v1/auth/password/reset", new { emailOrPhone = Email, role = "Shipper", code, newPassword = "kisa" });
        var reset = await c.PostAsJsonAsync("/api/v1/auth/password/reset", new { emailOrPhone = Email, role = "Shipper", code, newPassword = "YeniSifre9" });
        var reuse = await c.PostAsJsonAsync("/api/v1/auth/password/reset", new { emailOrPhone = Email, role = "Shipper", code, newPassword = "BaskaSifre9" });
        var oldPassword = await Login(c);
        var newPassword = await Login(c, "YeniSifre9");
        var oldRefresh = await c.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = session.GetProperty("refreshToken").GetString(), deviceId = "d1" });

        Assert.Equal(2, mail.Sent.Count);
        Assert.Contains("şifre", mail.Sent.Last().Subject);
        Assert.Equal(HttpStatusCode.BadRequest, weak.StatusCode);          // şifre kuralı kayıttakiyle aynı
        Assert.Equal(HttpStatusCode.NoContent, reset.StatusCode);         // zayıf şifre denemesi kodu yakmadı
        Assert.Equal(HttpStatusCode.BadRequest, reuse.StatusCode);        // kod tek kullanımlık
        Assert.Equal(HttpStatusCode.Unauthorized, oldPassword.StatusCode);
        Assert.Equal(HttpStatusCode.OK, newPassword.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, oldRefresh.StatusCode); // eski oturum kapandı
    }

    [Fact]
    public async Task A_code_dies_after_five_wrong_attempts()
    {
        var (c, mail) = await StartAsync();
        await Register(c);
        var code = mail.LastCode(Email);
        var wrong = code == "123456" ? "654321" : "123456";

        for (var i = 0; i < 5; i++)
            Assert.Equal(HttpStatusCode.BadRequest, (await c.PostAsJsonAsync("/api/v1/auth/verify-email", new { emailOrPhone = Email, role = "Shipper", code = wrong })).StatusCode);
        var right = await c.PostAsJsonAsync("/api/v1/auth/verify-email", new { emailOrPhone = Email, role = "Shipper", code });

        Assert.Equal(HttpStatusCode.BadRequest, right.StatusCode); // 5 yanlıştan sonra doğru kod da geçmez → yeni kod istenmeli
    }

    [Fact]
    public async Task Forgot_password_also_works_with_the_phone_number_and_the_code_goes_to_the_email()
    {
        var (c, mail) = await StartAsync();
        await Register(c);
        await c.PostAsJsonAsync("/api/v1/auth/verify-email", new { emailOrPhone = "0532 111 22 33", role = "Shipper", code = mail.LastCode(Email) });

        var forgot = await c.PostAsJsonAsync("/api/v1/auth/password/forgot", new { emailOrPhone = "+90 532 111 22 33", role = "Shipper" });
        var reset = await c.PostAsJsonAsync("/api/v1/auth/password/reset",
            new { emailOrPhone = "05321112233", role = "Shipper", code = mail.LastCode(Email), newPassword = "YeniSifre9" });

        Assert.Equal(HttpStatusCode.NoContent, forgot.StatusCode);
        Assert.Equal(2, mail.Sent.Count);
        Assert.All(mail.Sent, m => Assert.Equal(Email, m.To)); // telefonla istense de kod e-postaya gider
        Assert.Equal(HttpStatusCode.NoContent, reset.StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await Login(c, "YeniSifre9")).StatusCode);
    }
}
