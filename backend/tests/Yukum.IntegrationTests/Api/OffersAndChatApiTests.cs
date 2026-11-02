using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Time.Testing;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Api;

// Teklif ve sohbet akışı: gerçek API + gerçek SQL Server, uçtan uca (iOS'un yaptığı çağrıların aynısı).
// Odak: yetki matrisi (kim neyi yapabilir), kabul/red sonuçları, geçmiş silme, sohbet erişimi.
[Collection("SqlServer")]
public class OffersAndChatApiTests(SqlServerFixture sql)
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 25, 9, 0, 0, TimeSpan.Zero);
    private static int _counter; // her kullanıcıya benzersiz e-posta/telefon

    // ---------- yardımcılar ----------
    private async Task<HttpClient> StartAsync()
    {
        var database = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));
        return new YukumApiFactory()
            .WithWebHostBuilder(builder => builder.UseSetting("ConnectionStrings:DefaultConnection", database.ConnectionString))
            .CreateClient();
    }

    private static async Task<JsonElement> Json(HttpResponseMessage r) =>
        JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement;

    // İstek: jeton başlığıyla (jeton null ise anonim).
    private static async Task<HttpResponseMessage> Call(HttpClient c, string? token, HttpMethod method, string url, object? body = null)
    {
        var request = new HttpRequestMessage(method, url);
        if (token is not null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (body is not null) request.Content = JsonContent.Create(body);
        return await c.SendAsync(request);
    }

    // Kayıt + giriş → jeton.
    private static async Task<string> NewUser(HttpClient c, bool shipper)
    {
        var n = Interlocked.Increment(ref _counter);
        var email = $"u{n}@x.com";
        var phone = $"0532{1000000 + n}";
        object body = shipper
            ? new { fullName = $"Yuk Veren {n}", email, phone, password = "Abcdefg1", cityId = 33, companyName = "Firma", taxNumber = "1234567890", taxOffice = "Mersin", kvkkAccepted = true }
            : new
            {
                fullName = $"Tasimaci {n}", email, phone, password = "Abcdefg1", homeCityId = 33, serviceCityIds = new[] { 33 },
                vehicles = new object[] { new { type = "Truck", plateNumber = "33 ABC 123", capacityKg = 24000, capacityVolume = 90 } },
                kvkkAccepted = true
            };
        var reg = await c.PostAsJsonAsync(shipper ? "/api/v1/auth/register/shipper" : "/api/v1/auth/register/carrier", body);
        Assert.Equal(HttpStatusCode.Created, reg.StatusCode);
        var login = await c.PostAsJsonAsync("/api/v1/auth/login", new { emailOrPhone = email, password = "Abcdefg1", deviceId = "d" + n, deviceName = "test" });
        return (await Json(login)).GetProperty("accessToken").GetString()!;
    }

    // Yük Veren bir ilan açar → ilan numarası.
    private static async Task<string> NewListing(HttpClient c, string shipperToken)
    {
        var from = (await Json(await c.GetAsync("/api/v1/cities/33/districts")))[0].GetProperty("id").GetInt32();
        var to = (await Json(await c.GetAsync("/api/v1/cities/34/districts")))[0].GetProperty("id").GetInt32();
        var r = await Call(c, shipperToken, HttpMethod.Post, "/api/v1/listings", new
        {
            title = "Test ilan", weightKg = 1000, vehicleType = "Truck", fromCityId = 33, fromDistrictId = from, toCityId = 34, toDistrictId = to,
            pickupDate = DateTime.UtcNow.AddDays(30).ToString("yyyy-MM-dd"), budget = 5000
        });
        Assert.Equal(HttpStatusCode.Created, r.StatusCode);
        return (await Json(r)).GetProperty("id").GetString()!;
    }

    private static async Task<string> NewOffer(HttpClient c, string carrierToken, string listingId, decimal amount = 1000)
    {
        var r = await Call(c, carrierToken, HttpMethod.Post, $"/api/v1/listings/{listingId}/offers", new { amount, note = "not" });
        Assert.Equal(HttpStatusCode.OK, r.StatusCode);
        return (await Json(r)).GetProperty("id").GetString()!;
    }

    // ---------- teklif verme ----------
    [Fact]
    public async Task Carrier_offer_twice_updates_the_same_offer()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);

        var first = await NewOffer(c, carrier, listing, 1000);
        var second = await NewOffer(c, carrier, listing, 900);

        Assert.Equal(first, second);   // aynı kayıt güncellendi, ikinci satır açılmadı
        var mine = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine"));
        Assert.Equal(1, mine.GetArrayLength());
        Assert.Equal(900, mine[0].GetProperty("amount").GetDecimal());
    }

    [Fact]
    public async Task Shipper_cannot_make_an_offer_and_carrier_cannot_open_a_listing()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);

        var offerByShipper = await Call(c, shipper, HttpMethod.Post, $"/api/v1/listings/{listing}/offers", new { amount = 100 });
        var listingByCarrier = await Call(c, carrier, HttpMethod.Post, "/api/v1/listings", new { title = "x" });

        Assert.Equal(HttpStatusCode.Forbidden, offerByShipper.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, listingByCarrier.StatusCode);
    }

    // ---------- Yük Veren yetkileri ----------
    [Fact]
    public async Task Shipper_sees_offers_only_on_own_listing_and_carrier_cannot_decide()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var other = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var offer = await NewOffer(c, carrier, listing);

        var own = await Call(c, shipper, HttpMethod.Get, $"/api/v1/listings/{listing}/offers");
        var foreign = await Call(c, other, HttpMethod.Get, $"/api/v1/listings/{listing}/offers");          // başkasının ilanı: 404
        var foreignAccept = await Call(c, other, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");        // başkasının teklifi: 404
        var carrierAccept = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");      // rol uygun değil: 403

        Assert.Equal(HttpStatusCode.OK, own.StatusCode);
        Assert.Equal(1, (await Json(own)).GetArrayLength());
        Assert.Equal(HttpStatusCode.NotFound, foreign.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, foreignAccept.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, carrierAccept.StatusCode);
    }

    // ---------- kabul / red ----------
    [Fact]
    public async Task Accept_assigns_the_listing_rejects_other_offers_and_closes_it_to_new_offers()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var a = await NewUser(c, false); var b = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var offerA = await NewOffer(c, a, listing, 1000); var offerB = await NewOffer(c, b, listing, 1200);

        var accept = await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offerA}/accept");
        var again = await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offerB}/accept");   // ilan artık atandı: 409
        var lateOffer = await Call(c, b, HttpMethod.Post, $"/api/v1/listings/{listing}/offers", new { amount = 500 }); // atanmış ilana teklif: 409
        var offers = await Json(await Call(c, shipper, HttpMethod.Get, $"/api/v1/listings/{listing}/offers"));
        var open = await Json(await Call(c, b, HttpMethod.Get, "/api/v1/listings"));

        Assert.Equal(HttpStatusCode.OK, accept.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, lateOffer.StatusCode);
        Assert.Equal("Accepted", offers.EnumerateArray().Single(o => o.GetProperty("id").GetString() == offerA).GetProperty("status").GetString());
        Assert.Equal("Rejected", offers.EnumerateArray().Single(o => o.GetProperty("id").GetString() == offerB).GetProperty("status").GetString());
        Assert.Equal(0, open.GetArrayLength());   // atanan ilan açık listeden düştü
    }

    [Fact]
    public async Task Rejected_carrier_can_reoffer_and_goes_back_to_pending()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var offer = await NewOffer(c, carrier, listing, 1000);
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/reject");

        var afterReject = (await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings")))[0].GetProperty("myOfferStatus").GetString();
        await NewOffer(c, carrier, listing, 800);
        var afterReoffer = (await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings")))[0].GetProperty("myOfferStatus").GetString();

        Assert.Equal("Rejected", afterReject);
        Assert.Equal("Pending", afterReoffer);
    }

    // ---------- bildirim rozeti ----------
    [Fact]
    public async Task Decision_creates_an_unseen_badge_until_the_carrier_marks_it_seen()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var offer = await NewOffer(c, carrier, await NewListing(c, shipper));
        var before = (await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine/unseen-count"))).GetProperty("count").GetInt32();

        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/reject");
        var unseen = (await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine/unseen-count"))).GetProperty("count").GetInt32();
        var isNew = (await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine")))[0].GetProperty("isNew").GetBoolean();
        var seen = await Call(c, carrier, HttpMethod.Post, "/api/v1/offers/mine/seen");
        var after = (await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine/unseen-count"))).GetProperty("count").GetInt32();

        Assert.Equal(0, before);
        Assert.Equal(1, unseen);
        Assert.True(isNew);
        Assert.Equal(HttpStatusCode.NoContent, seen.StatusCode);
        Assert.Equal(0, after);
    }

    // ---------- geçmiş silme ----------
    [Fact]
    public async Task Hide_removes_only_from_own_history_and_pending_offers_cannot_be_hidden()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var offer = await NewOffer(c, carrier, await NewListing(c, shipper));

        var pending = await Call(c, carrier, HttpMethod.Delete, $"/api/v1/offers/{offer}");       // bekleyen: 409
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/reject");
        var hidden = await Call(c, carrier, HttpMethod.Delete, $"/api/v1/offers/{offer}");        // karar verilmiş: 204
        var carrierList = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine"));
        var shipperHistory = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/offers/history"));   // Yük Veren hâlâ görür

        Assert.Equal(HttpStatusCode.Conflict, pending.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, hidden.StatusCode);
        Assert.Equal(0, carrierList.GetArrayLength());
        Assert.Equal(1, shipperHistory.GetArrayLength());
    }

    // ---------- sohbet ----------
    [Fact]
    public async Task Chat_works_between_the_two_parties_and_is_hidden_from_outsiders()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false); var outsider = await NewUser(c, false);
        var offer = await NewOffer(c, carrier, await NewListing(c, shipper));
        var url = $"/api/v1/offers/{offer}/messages";

        var sent = await Call(c, carrier, HttpMethod.Post, url, new { text = "Merhaba" });
        await Call(c, shipper, HttpMethod.Post, url, new { text = "1200 olur mu?" });
        var asShipper = await Json(await Call(c, shipper, HttpMethod.Get, url));
        var asCarrier = await Json(await Call(c, carrier, HttpMethod.Get, url));
        var outsiderGet = await Call(c, outsider, HttpMethod.Get, url);
        var outsiderPost = await Call(c, outsider, HttpMethod.Post, url, new { text = "ben de" });
        var empty = await Call(c, carrier, HttpMethod.Post, url, new { text = "  " });

        Assert.Equal(HttpStatusCode.Created, sent.StatusCode);
        Assert.Equal(2, asShipper.GetArrayLength());
        Assert.Equal("Merhaba", asShipper[0].GetProperty("text").GetString());
        Assert.False(asShipper[0].GetProperty("isMine").GetBoolean());   // Yük Veren için ilk mesaj karşı tarafın
        Assert.True(asCarrier[0].GetProperty("isMine").GetBoolean());    // Taşımacı için kendi mesajı
        Assert.Equal(HttpStatusCode.NotFound, outsiderGet.StatusCode);   // taraf olmayan sohbeti göremez
        Assert.Equal(HttpStatusCode.NotFound, outsiderPost.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, empty.StatusCode);
    }

    [Fact]
    public async Task Chat_is_read_only_after_the_offer_is_rejected()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var offer = await NewOffer(c, carrier, await NewListing(c, shipper));
        var url = $"/api/v1/offers/{offer}/messages";
        await Call(c, carrier, HttpMethod.Post, url, new { text = "Merhaba" });
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/reject");

        var write = await Call(c, carrier, HttpMethod.Post, url, new { text = "olmaz mı?" });
        var read = await Json(await Call(c, carrier, HttpMethod.Get, url));

        Assert.Equal(HttpStatusCode.Conflict, write.StatusCode);   // yazma kapalı
        Assert.Equal(1, read.GetArrayLength());                    // eski mesajlar okunur
    }
}
