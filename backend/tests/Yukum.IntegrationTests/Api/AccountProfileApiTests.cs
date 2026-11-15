using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Time.Testing;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Api;

// Hesap Bilgilerim + profil fotoğrafı (15 Kasım): gerçek API + gerçek SQL Server + geçici fotoğraf klasörü (YukumApiFactory.AvatarDirectory).
// Uçlar: GET/PUT /account/me, POST/DELETE /account/avatar, GET /avatars/{id}.
[Collection("SqlServer")]
public class AccountProfileApiTests(SqlServerFixture sql)
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 25, 9, 0, 0, TimeSpan.Zero);
    private static int _counter;

    private static readonly byte[] Png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52];

    private sealed record User(string Token, string Email, string Phone);

    private async Task<(YukumApiFactory Factory, HttpClient C)> StartAsync()
    {
        var database = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));
        var factory = new YukumApiFactory();
        var app = factory.WithWebHostBuilder(b => b.UseSetting("ConnectionStrings:DefaultConnection", database.ConnectionString));
        return (factory, app.CreateClient());
    }

    private static async Task<JsonElement> Json(HttpResponseMessage r) => JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement;

    private static async Task<HttpResponseMessage> Call(HttpClient c, string? token, HttpMethod method, string url, HttpContent? content = null)
    {
        var request = new HttpRequestMessage(method, url) { Content = content };
        if (token is not null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return await c.SendAsync(request);
    }

    private static async Task<User> NewUser(HttpClient c, bool shipper, string? phone = null)
    {
        var n = Interlocked.Increment(ref _counter);
        var email = $"ap{n}{Guid.NewGuid().ToString("N")[..8]}@x.com";
        phone ??= $"0535{4000000 + n}";
        object body = shipper
            ? new { fullName = $"Yuk Veren {n}", email, phone, password = "Abcdefg1", cityId = 33, kvkkAccepted = true, termsAccepted = true }
            : new { fullName = $"Tasimaci {n}", email, phone, password = "Abcdefg1", homeCityId = 33, kvkkAccepted = true, termsAccepted = true };
        Assert.Equal(HttpStatusCode.Created, (await c.PostAsJsonAsync(shipper ? "/api/v1/auth/register/shipper" : "/api/v1/auth/register/carrier", body)).StatusCode);
        var login = await c.PostAsJsonAsync("/api/v1/auth/login", new { emailOrPhone = email, password = "Abcdefg1", deviceId = "ap" + n, deviceName = "test" });
        return new User((await Json(login)).GetProperty("accessToken").GetString()!, email, phone);
    }

    private static object Body(string fullName, string phone, string? currentPassword = null, int? cityId = 34, string? companyName = null) =>
        new { fullName, phone, currentPassword, cityId, about = "Merhaba", companyName, taxNumber = "1234567890", taxOffice = "Mersin" };

    private static MultipartFormDataContent Photo(byte[] bytes, string name = "foto.png")
    {
        var form = new MultipartFormDataContent();
        var file = new ByteArrayContent(bytes);
        file.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        form.Add(file, "file", name);
        return form;
    }

    [Fact]
    public async Task Shipper_reads_and_updates_own_info_and_the_email_stays_the_same()
    {
        var (_, c) = await StartAsync();
        var u = await NewUser(c, shipper: true);

        var me = await Json(await Call(c, u.Token, HttpMethod.Get, "/api/v1/account/me"));
        Assert.Equal("Shipper", me.GetProperty("role").GetString());
        Assert.Equal(u.Email, me.GetProperty("email").GetString());
        Assert.Equal(33, me.GetProperty("cityId").GetInt32());

        var r = await Call(c, u.Token, HttpMethod.Put, "/api/v1/account/me", JsonContent.Create(Body("Yeni Ad", u.Phone, companyName: "Acme Lojistik")));
        Assert.Equal(HttpStatusCode.OK, r.StatusCode);
        var updated = await Json(r);
        Assert.Equal("Yeni Ad", updated.GetProperty("fullName").GetString());
        Assert.Equal("Acme Lojistik", updated.GetProperty("companyName").GetString());
        Assert.Equal(34, updated.GetProperty("cityId").GetInt32());
        Assert.Equal(u.Email, updated.GetProperty("email").GetString());
        Assert.Equal(JsonValueKind.Null, updated.GetProperty("averageRating").ValueKind); // Taşımacı alanı Yük Veren'de yok
    }

    [Fact]
    public async Task Carrier_gets_rating_fields_and_shipper_only_fields_are_ignored()
    {
        var (_, c) = await StartAsync();
        var u = await NewUser(c, shipper: false);

        var updated = await Json(await Call(c, u.Token, HttpMethod.Put, "/api/v1/account/me", JsonContent.Create(Body("Tasimaci X", u.Phone, companyName: "Yok Sayilir"))));
        Assert.Equal("Carrier", updated.GetProperty("role").GetString());
        Assert.Equal(34, updated.GetProperty("cityId").GetInt32());             // HomeCityId
        Assert.Equal(JsonValueKind.Null, updated.GetProperty("companyName").ValueKind);
        Assert.Equal(0, updated.GetProperty("ratingCount").GetInt32());
    }

    [Fact]
    public async Task Phone_change_needs_the_current_password_and_then_login_works_with_the_new_number()
    {
        var (_, c) = await StartAsync();
        var u = await NewUser(c, shipper: true);
        var newPhone = "0536" + Random.Shared.Next(1000000, 9999999);

        var noPassword = await Call(c, u.Token, HttpMethod.Put, "/api/v1/account/me", JsonContent.Create(Body("Ali", newPhone)));
        Assert.Equal(HttpStatusCode.BadRequest, noPassword.StatusCode);
        Assert.True((await Json(noPassword)).GetProperty("errors").TryGetProperty("currentPassword", out _));

        var wrong = await Call(c, u.Token, HttpMethod.Put, "/api/v1/account/me", JsonContent.Create(Body("Ali", newPhone, "Yanlis123")));
        Assert.Equal(HttpStatusCode.BadRequest, wrong.StatusCode); // 401 değil: iOS oturumu kapatmasın

        var ok = await Call(c, u.Token, HttpMethod.Put, "/api/v1/account/me", JsonContent.Create(Body("Ali", newPhone, "Abcdefg1")));
        Assert.Equal(HttpStatusCode.OK, ok.StatusCode);

        var login = await c.PostAsJsonAsync("/api/v1/auth/login", new { emailOrPhone = newPhone, password = "Abcdefg1", deviceId = "yeni", deviceName = "test" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
    }

    [Fact]
    public async Task A_number_used_by_another_account_of_the_same_role_is_a_conflict_but_another_role_is_fine()
    {
        var (_, c) = await StartAsync();
        var a = await NewUser(c, shipper: true);
        var b = await NewUser(c, shipper: true);
        var carrier = await NewUser(c, shipper: false);

        var sameRole = await Call(c, a.Token, HttpMethod.Put, "/api/v1/account/me", JsonContent.Create(Body("Ali", b.Phone, "Abcdefg1")));
        Assert.Equal(HttpStatusCode.Conflict, sameRole.StatusCode);

        var otherRole = await Call(c, a.Token, HttpMethod.Put, "/api/v1/account/me", JsonContent.Create(Body("Ali", carrier.Phone, "Abcdefg1")));
        Assert.Equal(HttpStatusCode.OK, otherRole.StatusCode); // K-022: aynı kişi iki rolde hesap açabilir
    }

    [Fact]
    public async Task Photo_upload_replace_view_and_remove()
    {
        var (factory, c) = await StartAsync();
        var u = await NewUser(c, shipper: false);
        var other = await NewUser(c, shipper: true);

        var first = await Call(c, u.Token, HttpMethod.Post, "/api/v1/account/avatar", Photo(Png));
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var firstUrl = (await Json(first)).GetProperty("avatarUrl").GetString()!;
        Assert.Single(Directory.GetFiles(factory.AvatarDirectory));

        // Giriş yapmış başka kullanıcı görebilir; jetonsuz göremez. İçerik aynen döner, telefon önbelleğe alabilir.
        var view = await Call(c, other.Token, HttpMethod.Get, firstUrl);
        Assert.Equal(HttpStatusCode.OK, view.StatusCode);
        Assert.Equal("image/png", view.Content.Headers.ContentType!.MediaType);
        Assert.Equal(Png, await view.Content.ReadAsByteArrayAsync());
        Assert.Contains("immutable", view.Headers.CacheControl!.ToString());
        Assert.Equal(HttpStatusCode.Unauthorized, (await Call(c, null, HttpMethod.Get, firstUrl)).StatusCode);

        // Yenisi yüklenince eskisi silinir
        var secondUrl = (await Json(await Call(c, u.Token, HttpMethod.Post, "/api/v1/account/avatar", Photo(Png)))).GetProperty("avatarUrl").GetString()!;
        Assert.NotEqual(firstUrl, secondUrl);
        Assert.Equal(HttpStatusCode.NotFound, (await Call(c, u.Token, HttpMethod.Get, firstUrl)).StatusCode);
        Assert.Single(Directory.GetFiles(factory.AvatarDirectory));
        Assert.Equal(secondUrl, (await Json(await Call(c, u.Token, HttpMethod.Get, "/api/v1/account/me"))).GetProperty("avatarUrl").GetString());

        // Kaldır
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, u.Token, HttpMethod.Delete, "/api/v1/account/avatar")).StatusCode);
        Assert.Empty(Directory.GetFiles(factory.AvatarDirectory));
        Assert.Equal(JsonValueKind.Null, (await Json(await Call(c, u.Token, HttpMethod.Get, "/api/v1/account/me"))).GetProperty("avatarUrl").ValueKind);
    }

    [Fact]
    public async Task A_file_named_like_a_photo_but_not_an_image_is_rejected()
    {
        var (factory, c) = await StartAsync();
        var u = await NewUser(c, shipper: true);

        var r = await Call(c, u.Token, HttpMethod.Post, "/api/v1/account/avatar", Photo("<html>kötü</html>"u8.ToArray(), "foto.png"));
        Assert.Equal(HttpStatusCode.BadRequest, r.StatusCode);
        Assert.Empty(Directory.GetFiles(factory.AvatarDirectory));
    }

    [Fact]
    public async Task Deleting_the_account_also_deletes_the_photo_file()
    {
        var (factory, c) = await StartAsync();
        var u = await NewUser(c, shipper: true);
        Assert.Equal(HttpStatusCode.OK, (await Call(c, u.Token, HttpMethod.Post, "/api/v1/account/avatar", Photo(Png))).StatusCode);

        var delete = await Call(c, u.Token, HttpMethod.Post, "/api/v1/account/delete", JsonContent.Create(new { password = "Abcdefg1" }));
        Assert.Equal(HttpStatusCode.NoContent, delete.StatusCode);
        Assert.Empty(Directory.GetFiles(factory.AvatarDirectory));
    }

    // ─── 8. adım (15 Kasım): birbirinin profilini görme + İlanlarım ───

    private static async Task<string> NewListing(HttpClient c, string shipperToken)
    {
        var from = (await Json(await c.GetAsync("/api/v1/cities/33/districts")))[0].GetProperty("id").GetInt32();
        var to = (await Json(await c.GetAsync("/api/v1/cities/34/districts")))[0].GetProperty("id").GetInt32();
        var r = await Call(c, shipperToken, HttpMethod.Post, "/api/v1/listings", JsonContent.Create(new
        {
            title = "Profil ilanı", weightKg = 1000, vehicleType = "Truck", fromCityId = 33, fromDistrictId = from, toCityId = 34, toDistrictId = to,
            pickupDate = DateTime.UtcNow.AddDays(30).ToString("yyyy-MM-dd"), budget = 5000
        }));
        Assert.Equal(HttpStatusCode.Created, r.StatusCode);
        return (await Json(r)).GetProperty("id").GetString()!;
    }

    [Fact]
    public async Task A_carrier_sees_the_shippers_public_profile_without_contact_or_tax_details()
    {
        var (_, c) = await StartAsync();
        var shipper = await NewUser(c, shipper: true);
        var carrier = await NewUser(c, shipper: false);
        Assert.Equal(HttpStatusCode.OK, (await Call(c, shipper.Token, HttpMethod.Put, "/api/v1/account/me",
            JsonContent.Create(Body("Ayse Kaya", shipper.Phone, companyName: "Kaya Gida")))).StatusCode); // vergi no 1234567890, Mersin
        var listingId = await NewListing(c, shipper.Token);

        // Taşımacı ilanı görür → ilanda sahibi var → profiline gider
        var shipperId = (await Json(await Call(c, shipper.Token, HttpMethod.Get, "/api/v1/account/me"))).GetProperty("id").GetString()!;
        var r = await Call(c, carrier.Token, HttpMethod.Get, $"/api/v1/shippers/{shipperId}");
        Assert.Equal(HttpStatusCode.OK, r.StatusCode);
        var raw = await r.Content.ReadAsStringAsync();
        var p = JsonDocument.Parse(raw).RootElement;
        Assert.Equal("Ayse Kaya", p.GetProperty("fullName").GetString());
        Assert.Equal("Kaya Gida", p.GetProperty("companyName").GetString());
        Assert.Equal("İstanbul", p.GetProperty("cityName").GetString());
        Assert.Equal(1, p.GetProperty("openListingCount").GetInt32());
        Assert.Equal(0, p.GetProperty("completedListingCount").GetInt32());
        // Gizlilik: iletişim ve vergi bilgisi cevabın HİÇBİR yerinde yok
        Assert.DoesNotContain(shipper.Email, raw);
        Assert.DoesNotContain("1234567890", raw);
        Assert.DoesNotContain("phone", raw, StringComparison.OrdinalIgnoreCase);

        // Taşımacı numarası verilirse Yük Veren profili yoktur
        var carrierId = (await Json(await Call(c, carrier.Token, HttpMethod.Get, "/api/v1/account/me"))).GetProperty("id").GetString()!;
        Assert.Equal(HttpStatusCode.NotFound, (await Call(c, shipper.Token, HttpMethod.Get, $"/api/v1/shippers/{carrierId}")).StatusCode);
        _ = listingId;
    }

    [Fact]
    public async Task The_carrier_profile_now_carries_photo_city_and_member_since()
    {
        var (_, c) = await StartAsync();
        var carrier = await NewUser(c, shipper: false);
        var shipper = await NewUser(c, shipper: true);
        var url = (await Json(await Call(c, carrier.Token, HttpMethod.Post, "/api/v1/account/avatar", Photo(Png)))).GetProperty("avatarUrl").GetString();
        var carrierId = (await Json(await Call(c, carrier.Token, HttpMethod.Get, "/api/v1/account/me"))).GetProperty("id").GetString()!;

        var p = await Json(await Call(c, shipper.Token, HttpMethod.Get, $"/api/v1/carriers/{carrierId}"));
        Assert.Equal(url, p.GetProperty("avatarUrl").GetString());
        Assert.Equal("Mersin", p.GetProperty("cityName").GetString());
        Assert.True(p.GetProperty("memberSince").GetDateTime().Year >= 2026);
    }

    [Fact]
    public async Task My_listings_with_all_include_closed_ones_with_status_and_owner()
    {
        var (_, c) = await StartAsync();
        var shipper = await NewUser(c, shipper: true);
        var open = await NewListing(c, shipper.Token);
        var removed = await NewListing(c, shipper.Token);
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, shipper.Token, HttpMethod.Post, $"/api/v1/listings/{removed}/cancel")).StatusCode);

        var onlyOpen = await Json(await Call(c, shipper.Token, HttpMethod.Get, "/api/v1/listings/mine"));
        Assert.Equal(open, Assert.Single(onlyOpen.EnumerateArray()).GetProperty("id").GetString());

        var all = (await Json(await Call(c, shipper.Token, HttpMethod.Get, "/api/v1/listings/mine?all=true"))).EnumerateArray().ToList();
        Assert.Equal(2, all.Count);
        Assert.Equal("Cancelled", all.Single(l => l.GetProperty("id").GetString() == removed).GetProperty("status").GetString());
        var me = (await Json(await Call(c, shipper.Token, HttpMethod.Get, "/api/v1/account/me"))).GetProperty("id").GetString();
        Assert.All(all, l => Assert.Equal(me, l.GetProperty("shipperId").GetString()));
    }
}
