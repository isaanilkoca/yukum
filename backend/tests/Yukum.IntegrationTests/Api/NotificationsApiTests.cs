using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Time.Testing;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Api;

// Uygulama içi bildirimler: olay olunca doğru kişiye bildirim yazılır, kişi yalnız kendi bildirimlerini görür ve okundu yapar.
[Collection("SqlServer")]
public class NotificationsApiTests(SqlServerFixture sql)
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 25, 9, 0, 0, TimeSpan.Zero);
    private static int _counter;

    private async Task<HttpClient> StartAsync()
    {
        var database = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));
        return new YukumApiFactory()
            .WithWebHostBuilder(builder => builder.UseSetting("ConnectionStrings:DefaultConnection", database.ConnectionString))
            .CreateClient();
    }

    private static async Task<JsonElement> Json(HttpResponseMessage r) => JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement;

    private static async Task<HttpResponseMessage> Call(HttpClient c, string? token, HttpMethod method, string url, object? body = null)
    {
        var request = new HttpRequestMessage(method, url);
        if (token is not null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (body is not null) request.Content = JsonContent.Create(body);
        return await c.SendAsync(request);
    }

    private static async Task<string> NewUser(HttpClient c, bool shipper)
    {
        var n = Interlocked.Increment(ref _counter);
        var email = $"n{n}@x.com";
        var phone = $"0533{2000000 + n}";
        object body = shipper
            ? new { fullName = $"Yuk Veren {n}", email, phone, password = "Abcdefg1", cityId = 33, kvkkAccepted = true }
            : new
            {
                fullName = $"Tasimaci {n}", email, phone, password = "Abcdefg1", homeCityId = 33, serviceCityIds = new[] { 33 },
                vehicles = new object[] { new { type = "Truck", capacityKg = 24000, brand = "Volvo", model = "FH", year = 2020 } }, kvkkAccepted = true
            };
        Assert.Equal(HttpStatusCode.Created, (await c.PostAsJsonAsync(shipper ? "/api/v1/auth/register/shipper" : "/api/v1/auth/register/carrier", body)).StatusCode);
        var login = await c.PostAsJsonAsync("/api/v1/auth/login", new { emailOrPhone = email, password = "Abcdefg1", deviceId = "nd" + n, deviceName = "test" });
        return (await Json(login)).GetProperty("accessToken").GetString()!;
    }

    private static async Task<string> NewListing(HttpClient c, string shipperToken)
    {
        var from = (await Json(await c.GetAsync("/api/v1/cities/33/districts")))[0].GetProperty("id").GetInt32();
        var to = (await Json(await c.GetAsync("/api/v1/cities/34/districts")))[0].GetProperty("id").GetInt32();
        var r = await Call(c, shipperToken, HttpMethod.Post, "/api/v1/listings", new
        {
            title = "Bildirim ilanı", weightKg = 1000, vehicleType = "Truck", fromCityId = 33, fromDistrictId = from, toCityId = 34, toDistrictId = to,
            pickupDate = DateTime.UtcNow.AddDays(30).ToString("yyyy-MM-dd"), budget = 5000
        });
        Assert.Equal(HttpStatusCode.Created, r.StatusCode);
        return (await Json(r)).GetProperty("id").GetString()!;
    }

    private static async Task<string> NewOffer(HttpClient c, string carrierToken, string listingId, decimal amount = 1000)
    {
        var r = await Call(c, carrierToken, HttpMethod.Post, $"/api/v1/listings/{listingId}/offers", new { estimatedDeliveryDate = DateTime.UtcNow.AddDays(45).ToString("yyyy-MM-dd"), amount, note = "not" });
        Assert.Equal(HttpStatusCode.OK, r.StatusCode);
        return (await Json(r)).GetProperty("id").GetString()!;
    }

    // Kullanıcının bildirim türleri (yeniden eskiye) ve okunmamış sayısı
    private static async Task<string[]> Types(HttpClient c, string token) =>
        (await Json(await Call(c, token, HttpMethod.Get, "/api/v1/notifications"))).GetProperty("items").EnumerateArray()
            .Select(n => n.GetProperty("type").ToString()).ToArray();

    private static async Task<int> Unread(HttpClient c, string token) =>
        (await Json(await Call(c, token, HttpMethod.Get, "/api/v1/notifications/unread-count"))).GetProperty("count").GetInt32();

    [Fact]
    public async Task Every_step_of_a_job_notifies_the_right_person_in_the_same_transaction()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false); var other = await NewUser(c, false);
        var listing = await NewListing(c, shipper);

        var offer = await NewOffer(c, carrier, listing);                        // Yük Veren: teklif geldi
        await NewOffer(c, other, listing, 1200);                                // Yük Veren: ikinci teklif
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/accept"); // Taşımacı: kabul; diğeri: reddedildi
        await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/advance"); // Yük Veren: yük alındı
        await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/advance");
        await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/advance");
        await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/complete"); // Yük Veren: tamamlandı
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/review", new { rating = 5, comment = "iyi" }); // Taşımacı: puan

        Assert.Equal(new[] { "ReviewReceived", "OfferAccepted" } /* aşama ve tamamlama bildirimi karşı tarafa (Yük Veren) gider */, await Types(c, carrier));
        var shipperTypes = await Types(c, shipper);
        Assert.Equal(new[] { "JobCompleted", "JobStageChanged", "JobStageChanged", "JobStageChanged", "OfferReceived", "OfferReceived" }, shipperTypes);
        Assert.Equal(new[] { "OfferRejected" }, await Types(c, other));          // ilan başkasına verildi
    }

    [Fact]
    public async Task A_second_offer_from_the_same_carrier_says_updated_and_text_has_no_personal_data()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        await NewOffer(c, carrier, listing, 1000);
        await NewOffer(c, carrier, listing, 900);

        var items = (await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/notifications"))).GetProperty("items");
        Assert.Equal("Teklif güncellendi", items[0].GetProperty("title").GetString());
        Assert.Equal("Yeni teklif", items[1].GetProperty("title").GetString());
        var body = items[0].GetProperty("body").GetString()!;
        Assert.Contains("Bildirim ilanı", body);
        Assert.DoesNotContain("Tasimaci", body);          // karşı tarafın adı yazılmaz
        Assert.Equal(listing, items[0].GetProperty("listingId").GetString());
    }

    [Fact]
    public async Task Marking_read_is_idempotent_and_read_all_clears_the_badge()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        await NewOffer(c, carrier, listing, 1000);
        await NewOffer(c, carrier, listing, 900);
        Assert.Equal(2, await Unread(c, shipper));

        var first = (await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/notifications"))).GetProperty("items")[0].GetProperty("id").GetString();
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, shipper, HttpMethod.Post, $"/api/v1/notifications/{first}/read")).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, shipper, HttpMethod.Post, $"/api/v1/notifications/{first}/read")).StatusCode); // ikinci kez de başarılı
        Assert.Equal(1, await Unread(c, shipper));

        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, shipper, HttpMethod.Post, "/api/v1/notifications/read-all")).StatusCode);
        Assert.Equal(0, await Unread(c, shipper));
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, shipper, HttpMethod.Post, "/api/v1/notifications/read-all")).StatusCode); // okunmamış yokken de hata vermez
    }

    [Fact]
    public async Task A_user_sees_and_marks_only_own_notifications_and_anonymous_is_refused()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        await NewOffer(c, carrier, await NewListing(c, shipper));
        var id = (await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/notifications"))).GetProperty("items")[0].GetProperty("id").GetString();

        Assert.Empty(await Types(c, carrier));                                                                    // Taşımacı'nın listesinde yok
        Assert.Equal(HttpStatusCode.NotFound, (await Call(c, carrier, HttpMethod.Post, $"/api/v1/notifications/{id}/read")).StatusCode); // başkasının: 404
        Assert.Equal(1, await Unread(c, shipper));                                                                // dokunulmadı
        Assert.Equal(HttpStatusCode.NotFound, (await Call(c, shipper, HttpMethod.Post, $"/api/v1/notifications/{Guid.NewGuid()}/read")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await Call(c, null, HttpMethod.Get, "/api/v1/notifications")).StatusCode);
    }

    [Fact]
    public async Task Deleting_removes_only_own_notification_updates_the_badge_and_is_idempotent()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        await NewOffer(c, carrier, listing); await NewOffer(c, carrier, listing, 900);
        Assert.Equal(2, await Unread(c, shipper));
        var id = (await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/notifications"))).GetProperty("items")[0].GetProperty("id").GetString();

        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, carrier, HttpMethod.Delete, $"/api/v1/notifications/{id}")).StatusCode); // başkası: cevap aynı (sızdırmaz)
        Assert.Equal(2, await Unread(c, shipper));                                                                                     // ama satıra dokunulmadı

        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, shipper, HttpMethod.Delete, $"/api/v1/notifications/{id}")).StatusCode);
        var after = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/notifications"));
        Assert.Equal(1, after.GetProperty("totalCount").GetInt32());
        Assert.DoesNotContain(after.GetProperty("items").EnumerateArray(), n => n.GetProperty("id").GetString() == id);
        Assert.Equal(1, await Unread(c, shipper));                                                                                     // okunmamış silinince rozet de düşer

        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, shipper, HttpMethod.Delete, $"/api/v1/notifications/{id}")).StatusCode); // ikinci kez de başarılı
        Assert.Equal(HttpStatusCode.Unauthorized, (await Call(c, null, HttpMethod.Delete, $"/api/v1/notifications/{id}")).StatusCode);
    }

    [Fact]
    public async Task The_list_is_paged_newest_first_without_repeats()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        for (var i = 0; i < 5; i++) await NewOffer(c, carrier, listing, 1000 - i);

        var page1 = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/notifications?page=1&pageSize=2"));
        var page3 = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/notifications?page=3&pageSize=2"));
        var all = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/notifications?page=1&pageSize=50"));

        Assert.Equal(5, page1.GetProperty("totalCount").GetInt32());
        Assert.Equal(2, page1.GetProperty("items").GetArrayLength());
        Assert.Equal(1, page3.GetProperty("items").GetArrayLength());
        Assert.Equal(5, all.GetProperty("items").EnumerateArray().Select(n => n.GetProperty("id").GetString()).Distinct().Count());
    }

    [Fact]
    public async Task Removing_a_listing_or_deleting_the_shippers_account_notifies_the_carriers()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false); var carrier2 = await NewUser(c, false);
        var cancelled = await NewListing(c, shipper);
        await NewOffer(c, carrier, cancelled);
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/listings/{cancelled}/cancel");
        Assert.Equal("ListingCancelled", (await Types(c, carrier))[0]);

        await NewOffer(c, carrier2, await NewListing(c, shipper));
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, shipper, HttpMethod.Post, "/api/v1/account/delete", new { password = "Abcdefg1" })).StatusCode);
        Assert.Equal("ListingCancelled", (await Types(c, carrier2))[0]);   // hesap silinince açık ilandaki teklif sahibi haberdar olur
    }
}
