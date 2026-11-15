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

    // Taşımacı ilan listesi sayfalı zarf döner ({ items, page, pageSize, totalCount }); eski testler yalnız ilan dizisine bakar.
    private static async Task<JsonElement> Items(HttpResponseMessage r) => (await Json(r)).GetProperty("items");

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
            ? new { fullName = $"Yuk Veren {n}", email, phone, password = "Abcdefg1", cityId = 33, companyName = "Firma", taxNumber = "1234567890", taxOffice = "Mersin", kvkkAccepted = true, termsAccepted = true }
            : new
            {
                fullName = $"Tasimaci {n}", email, phone, password = "Abcdefg1", homeCityId = 33, serviceCityIds = new[] { 33 },
                vehicles = new object[] { new { type = "Truck", plateNumber = "33 ABC 123", capacityKg = 24000, capacityVolume = 90, brand = "Mercedes-Benz", model = "Actros", year = 2019 } },
                kvkkAccepted = true, termsAccepted = true
            };
        var reg = await c.PostAsJsonAsync(shipper ? "/api/v1/auth/register/shipper" : "/api/v1/auth/register/carrier", body);
        Assert.Equal(HttpStatusCode.Created, reg.StatusCode);
        var login = await c.PostAsJsonAsync("/api/v1/auth/login", new { emailOrPhone = email, password = "Abcdefg1", deviceId = "d" + n, deviceName = "test" });
        return (await Json(login)).GetProperty("accessToken").GetString()!;
    }

    // Yük Veren bir ilan açar → ilan numarası.
    private static async Task<string> NewListing(HttpClient c, string shipperToken, int fromCityId = 33)
    {
        var from = (await Json(await c.GetAsync($"/api/v1/cities/{fromCityId}/districts")))[0].GetProperty("id").GetInt32();
        var to = (await Json(await c.GetAsync("/api/v1/cities/34/districts")))[0].GetProperty("id").GetInt32();
        var r = await Call(c, shipperToken, HttpMethod.Post, "/api/v1/listings", new
        {
            title = "Test ilan", weightKg = 1000, vehicleType = "Truck", fromCityId, fromDistrictId = from, toCityId = 34, toDistrictId = to,
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

    // ---------- filtre ----------
    // Taşımacı işi baştan sona ilerletir: yük alındı → yolda → teslim edildi (3 kez advance)
    private static async Task Deliver(HttpClient c, string carrierToken, string offerId)
    {
        for (var i = 0; i < 3; i++)
            Assert.Equal(HttpStatusCode.OK, (await Call(c, carrierToken, HttpMethod.Post, $"/api/v1/offers/{offerId}/advance")).StatusCode);
    }

    [Fact]
    public async Task Open_listings_can_be_filtered_by_departure_city_and_district()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        await NewListing(c, shipper, fromCityId: 33);   // Mersin çıkışlı
        await NewListing(c, shipper, fromCityId: 1);    // Adana çıkışlı
        var mersinDistricts = await Json(await c.GetAsync("/api/v1/cities/33/districts"));
        var otherDistrict = mersinDistricts[1].GetProperty("id").GetInt32();   // ilanın ilçesi [0], bu başka bir ilçe

        var all = await Items(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings"));
        var adana = await Items(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings?fromCityId=1"));
        var wrongDistrict = await Items(await Call(c, carrier, HttpMethod.Get, $"/api/v1/listings?fromCityId=33&fromDistrictId={otherDistrict}"));

        Assert.Equal(2, all.GetArrayLength());                                   // filtre yok: hepsi
        Assert.Equal(1, adana.GetArrayLength());                                 // il filtresi
        Assert.Equal("Adana", adana[0].GetProperty("fromCityName").GetString());
        Assert.Equal(0, wrongDistrict.GetArrayLength());                         // il doğru, ilçe başka: boş
    }

    // ---------- aşırı büyük değerler: 500 değil 400 ----------
    [Fact]
    public async Task Huge_budget_weight_or_offer_amount_returns_400_not_500()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var from = (await Json(await c.GetAsync("/api/v1/cities/33/districts")))[0].GetProperty("id").GetInt32();
        var to = (await Json(await c.GetAsync("/api/v1/cities/34/districts")))[0].GetProperty("id").GetInt32();
        object Body(long weight, long budget) => new
        {
            title = "x", weightKg = weight, vehicleType = "Truck", fromCityId = 33, fromDistrictId = from, toCityId = 34, toDistrictId = to,
            pickupDate = DateTime.UtcNow.AddDays(30).ToString("yyyy-MM-dd"), budget
        };

        var hugeBudget = await Call(c, shipper, HttpMethod.Post, "/api/v1/listings", Body(1000, 123123123122));
        var hugeWeight = await Call(c, shipper, HttpMethod.Post, "/api/v1/listings", Body(5_000_000, 5000));
        var hugeOffer = await Call(c, carrier, HttpMethod.Post, $"/api/v1/listings/{listing}/offers", new { estimatedDeliveryDate = DateTime.UtcNow.AddDays(45).ToString("yyyy-MM-dd"), amount = 123123123122m });

        Assert.Equal(HttpStatusCode.BadRequest, hugeBudget.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, hugeWeight.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, hugeOffer.StatusCode);
    }

    // ---------- konuma göre sıralama ----------
    [Fact]
    public async Task Open_listings_are_sorted_by_distance_when_a_location_is_given()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        await NewListing(c, shipper, fromCityId: 33);   // Mersin çıkışlı
        await NewListing(c, shipper, fromCityId: 22);   // Edirne çıkışlı

        var nearIstanbul = await Items(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings?lat=41.0&lon=29.0"));
        var nearMersin = await Items(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings?lat=36.8&lon=34.6"));
        var noLocation = await Items(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings"));

        Assert.Equal("Edirne", nearIstanbul[0].GetProperty("fromCityName").GetString());   // İstanbul'a Edirne yakın
        Assert.Equal("Mersin", nearMersin[0].GetProperty("fromCityName").GetString());     // Mersin'dekine Mersin yakın
        Assert.True(nearIstanbul[0].GetProperty("distanceKm").GetDouble() < nearIstanbul[1].GetProperty("distanceKm").GetDouble());
        Assert.Equal(JsonValueKind.Null, noLocation[0].GetProperty("distanceKm").ValueKind);   // konum yoksa mesafe de yok
    }

    [Theory]
    [InlineData("lat=41.0")]                 // yalnız enlem
    [InlineData("lat=95&lon=29")]            // enlem aralık dışı
    [InlineData("lat=41&lon=200")]           // boylam aralık dışı
    public async Task Invalid_location_returns_400(string query)
    {
        var c = await StartAsync();
        var carrier = await NewUser(c, false);

        var response = await Call(c, carrier, HttpMethod.Get, "/api/v1/listings?" + query);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
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

        var offerByShipper = await Call(c, shipper, HttpMethod.Post, $"/api/v1/listings/{listing}/offers", new { estimatedDeliveryDate = DateTime.UtcNow.AddDays(45).ToString("yyyy-MM-dd"), amount = 100 });
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
        var lateOffer = await Call(c, b, HttpMethod.Post, $"/api/v1/listings/{listing}/offers", new { estimatedDeliveryDate = DateTime.UtcNow.AddDays(45).ToString("yyyy-MM-dd"), amount = 500 }); // atanmış ilana teklif: 409
        var offers = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/offers/history"));   // kabul/red verilenler geçmişte
        var open = await Items(await Call(c, b, HttpMethod.Get, "/api/v1/listings"));
        var pendingLeft = await Json(await Call(c, shipper, HttpMethod.Get, $"/api/v1/listings/{listing}/offers"));

        Assert.Equal(HttpStatusCode.OK, accept.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, lateOffer.StatusCode);
        Assert.Equal("Accepted", offers.EnumerateArray().Single(o => o.GetProperty("id").GetString() == offerA).GetProperty("status").GetString());
        Assert.Equal("Rejected", offers.EnumerateArray().Single(o => o.GetProperty("id").GetString() == offerB).GetProperty("status").GetString());
        Assert.Equal(0, open.GetArrayLength());   // atanan ilan açık listeden düştü
        Assert.Equal(0, pendingLeft.GetArrayLength());   // "Gelen teklifler" yalnız bekleyenleri gösterir; karar verilenler geçmişe gitti
    }

    [Fact]
    public async Task Main_list_shows_only_untouched_listings_and_offered_ones_move_to_my_offers()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var untouched = await NewListing(c, shipper); var offered = await NewListing(c, shipper);

        var before = await Items(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings"));
        var offer = await NewOffer(c, carrier, offered, 1000);
        var pending = await Items(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings"));          // bekleyen teklif: ana listeden kalktı
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/reject");
        var rejected = await Items(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings"));
        await Call(c, carrier, HttpMethod.Delete, $"/api/v1/offers/{offer}");                          // geçmişten silse de ana listeye dönmez
        var hidden = await Items(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings"));
        var mine = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine"));

        Assert.Equal(2, before.GetArrayLength());
        Assert.Equal(untouched, pending.EnumerateArray().Single().GetProperty("id").GetString());     // yalnız dokunulmamış kaldı
        Assert.Equal(1, rejected.GetArrayLength());
        Assert.Equal(1, hidden.GetArrayLength());
        Assert.Equal(0, mine.GetArrayLength());                                                       // silinen Tekliflerim'den de gitti
    }

    [Fact]
    public async Task Offers_of_every_status_appear_in_my_offers()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var a = await NewOffer(c, carrier, await NewListing(c, shipper), 100);   // bekleyen kalacak
        var b = await NewOffer(c, carrier, await NewListing(c, shipper), 200);   // kabul
        var r = await NewOffer(c, carrier, await NewListing(c, shipper), 300);   // red
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{b}/accept");
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{r}/reject");

        var mine = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine"));
        var main = await Items(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings"));

        Assert.Equal(["Accepted", "Pending", "Rejected"], mine.EnumerateArray().Select(o => o.GetProperty("status").GetString()!).Order().ToArray());
        Assert.Equal(0, main.GetArrayLength());   // üçü de dokunulmuş, ana listede ilan kalmadı
        Assert.NotNull(a);
    }

    [Fact]
    public async Task Accepted_offer_is_an_active_job_and_cannot_be_deleted_by_either_side()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var offer = await NewOffer(c, carrier, await NewListing(c, shipper));
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");

        var byShipper = await Call(c, shipper, HttpMethod.Delete, $"/api/v1/offers/{offer}");
        var byCarrier = await Call(c, carrier, HttpMethod.Delete, $"/api/v1/offers/{offer}");
        var shipperSees = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/offers/history"));
        var carrierSees = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine"));
        var chat = await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/messages", new { text = "Merhaba" });

        Assert.Equal(HttpStatusCode.Conflict, byShipper.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, byCarrier.StatusCode);
        Assert.Equal(1, shipperSees.GetArrayLength());   // iki taraf da hâlâ görüyor
        Assert.Equal(1, carrierSees.GetArrayLength());
        Assert.Equal(HttpStatusCode.Created, chat.StatusCode);   // sohbet iki tarafta açık
    }

    // ---------- Yük Veren ana akışı: yalnız canlı iş ----------
    [Fact]
    public async Task Shipper_main_flow_shows_only_open_listings_and_pending_offers()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var live = await NewListing(c, shipper); var assigned = await NewListing(c, shipper);
        var offerLive = await NewOffer(c, carrier, live, 500); var offerAssigned = await NewOffer(c, carrier, assigned, 700);
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offerAssigned}/accept");

        var mine = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/listings/mine"));
        var pending = await Json(await Call(c, shipper, HttpMethod.Get, $"/api/v1/listings/{live}/offers"));
        var history = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/offers/history"));

        Assert.Equal(live, mine.EnumerateArray().Single().GetProperty("id").GetString());    // atanan ilan ana listeden kalktı
        Assert.Equal(offerLive, pending.EnumerateArray().Single().GetProperty("id").GetString());
        Assert.Equal(offerAssigned, history.EnumerateArray().Single().GetProperty("id").GetString());   // kabul edilen geçmişte
    }

    // ---------- sohbet silme: yalnız kendi tarafı ----------
    [Fact]
    public async Task Clearing_a_chat_hides_it_only_for_the_person_who_cleared_it()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var offer = await NewOffer(c, carrier, await NewListing(c, shipper));
        var url = $"/api/v1/offers/{offer}/messages";
        await Call(c, carrier, HttpMethod.Post, url, new { text = "Merhaba" });
        await Call(c, shipper, HttpMethod.Post, url, new { text = "Selam" });

        var clear = await Call(c, carrier, HttpMethod.Delete, url);                       // Taşımacı kendi sohbetini siler
        var carrierView = await Json(await Call(c, carrier, HttpMethod.Get, url));
        var shipperView = await Json(await Call(c, shipper, HttpMethod.Get, url));
        await Call(c, shipper, HttpMethod.Post, url, new { text = "Yeni mesaj" });          // silmeden SONRA yazılan mesaj görünür
        var carrierAfter = await Json(await Call(c, carrier, HttpMethod.Get, url));
        var outsiderClear = await Call(c, await NewUser(c, false), HttpMethod.Delete, url);

        Assert.Equal(HttpStatusCode.NoContent, clear.StatusCode);
        Assert.Equal(0, carrierView.GetArrayLength());     // Taşımacı'da gitti
        Assert.Equal(2, shipperView.GetArrayLength());     // Yük Veren'de durur
        Assert.Equal(1, carrierAfter.GetArrayLength());    // yalnız yeni mesaj
        Assert.Equal("Yeni mesaj", carrierAfter[0].GetProperty("text").GetString());
        Assert.Equal(HttpStatusCode.NotFound, outsiderClear.StatusCode);   // taraf olmayan silemez
    }

    // ---------- işi bitir ve sil ----------
    [Fact]
    public async Task Completing_a_job_locks_the_chat_for_both_sides_and_clears_it_only_for_the_one_who_completed()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var offer = await NewOffer(c, carrier, await NewListing(c, shipper));
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");
        var chat = $"/api/v1/offers/{offer}/messages";
        await Call(c, carrier, HttpMethod.Post, chat, new { text = "Yola çıktım" });
        await Call(c, shipper, HttpMethod.Post, chat, new { text = "Tamam" });

        await Deliver(c, carrier, offer);
        var complete = await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/complete");   // Yük Veren bitirir

        Assert.Equal(HttpStatusCode.OK, complete.StatusCode);
        Assert.Equal("Completed", (await Json(complete)).GetProperty("status").GetString());
        // sohbet İKİ tarafta da yazmaya kilitli
        Assert.Equal(HttpStatusCode.Conflict, (await Call(c, carrier, HttpMethod.Post, chat, new { text = "x" })).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await Call(c, shipper, HttpMethod.Post, chat, new { text = "x" })).StatusCode);
        // silme yalnız bitirende: Yük Veren'de mesajlar ve teklif gitti, Taşımacı'da durur (okunur)
        Assert.Equal(0, (await Json(await Call(c, shipper, HttpMethod.Get, chat))).GetArrayLength());
        Assert.Equal(2, (await Json(await Call(c, carrier, HttpMethod.Get, chat))).GetArrayLength());
        Assert.Equal(0, (await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/offers/history"))).GetArrayLength());
        Assert.Equal(0, (await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/listings/mine"))).GetArrayLength());
        var carrierMine = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine"));
        Assert.Equal("Completed", carrierMine[0].GetProperty("status").GetString());
        Assert.True(carrierMine[0].GetProperty("isNew").GetBoolean());   // Taşımacı'ya bildirim rozeti
        // Taşımacı kendi tarafını artık silebilir
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, carrier, HttpMethod.Delete, $"/api/v1/offers/{offer}")).StatusCode);
        Assert.Equal(0, (await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine"))).GetArrayLength());
    }

    [Fact]
    public async Task Carrier_can_complete_too_and_the_shipper_sees_it_as_completed()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var offer = await NewOffer(c, carrier, await NewListing(c, shipper));
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");

        await Deliver(c, carrier, offer);
        var complete = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/complete");
        var shipperHistory = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/offers/history"));
        var carrierMine = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine"));

        Assert.Equal(HttpStatusCode.OK, complete.StatusCode);
        Assert.Equal("Completed", shipperHistory.EnumerateArray().Single().GetProperty("status").GetString());   // Yük Veren'de Tamamlandı olarak durur
        Assert.Equal(0, carrierMine.GetArrayLength());   // bitiren Taşımacı'dan silindi
    }

    [Fact]
    public async Task Only_an_accepted_job_can_be_completed_and_only_by_a_participant()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false); var outsider = await NewUser(c, false);
        var offer = await NewOffer(c, carrier, await NewListing(c, shipper));

        var pending = await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/complete");     // bekleyen: 409
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");
        var byOutsider = await Call(c, outsider, HttpMethod.Post, $"/api/v1/offers/{offer}/complete");   // taraf değil: 404
        var notDelivered = await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/complete");  // teslim edilmeden: 409
        await Deliver(c, carrier, offer);
        var first = await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/complete");
        var again = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/complete");        // zaten tamamlandı: 409

        Assert.Equal(HttpStatusCode.Conflict, pending.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, byOutsider.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, notDelivered.StatusCode);
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
    }

    // ---------- ilanı yayından kaldır ----------
    [Fact]
    public async Task Cancelling_a_listing_removes_it_everywhere_and_notifies_carriers_with_a_locked_chat()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var a = await NewUser(c, false); var b = await NewUser(c, false);
        var listing = await NewListing(c, shipper); var other = await NewListing(c, shipper);
        var offerA = await NewOffer(c, a, listing, 1000); await NewOffer(c, b, listing, 1100);
        await Call(c, a, HttpMethod.Post, $"/api/v1/offers/{offerA}/messages", new { text = "Merhaba" });

        var cancel = await Call(c, shipper, HttpMethod.Post, $"/api/v1/listings/{listing}/cancel");

        Assert.Equal(HttpStatusCode.NoContent, cancel.StatusCode);
        // Yük Veren: yalnız diğer ilan kaldı; iptal edilen tekliflerle geçmişi kirlenmedi
        Assert.Equal(other, (await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/listings/mine"))).EnumerateArray().Single().GetProperty("id").GetString());
        Assert.Equal(0, (await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/offers/history"))).GetArrayLength());
        // Taşımacı: teklif "Cancelled", rozet var, ana listede ilan yok
        var mineA = await Json(await Call(c, a, HttpMethod.Get, "/api/v1/offers/mine"));
        Assert.Equal("Cancelled", mineA[0].GetProperty("status").GetString());
        Assert.True(mineA[0].GetProperty("isNew").GetBoolean());
        Assert.Equal(other, (await Items(await Call(c, a, HttpMethod.Get, "/api/v1/listings"))).EnumerateArray().Single().GetProperty("id").GetString());
        // sohbet kilitli ama eski mesajlar okunur
        Assert.Equal(HttpStatusCode.Conflict, (await Call(c, a, HttpMethod.Post, $"/api/v1/offers/{offerA}/messages", new { text = "x" })).StatusCode);
        Assert.Equal(1, (await Json(await Call(c, a, HttpMethod.Get, $"/api/v1/offers/{offerA}/messages"))).GetArrayLength());
        // yeni teklif verilemez, taşımacı iptal edileni silebilir
        Assert.Equal(HttpStatusCode.Conflict, (await Call(c, b, HttpMethod.Post, $"/api/v1/listings/{listing}/offers", new { estimatedDeliveryDate = DateTime.UtcNow.AddDays(45).ToString("yyyy-MM-dd"), amount = 5 })).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, a, HttpMethod.Delete, $"/api/v1/offers/{offerA}")).StatusCode);
    }

    [Fact]
    public async Task Cancelling_is_owner_only_and_not_allowed_on_an_assigned_job_delivered_or_not_nor_twice_or_after_completion()
    {
        // 15 Kasım kuralı: kabul edilmiş teklif varken ilan kaldırılamaz (teslim edilmemişse "teslim olmadan" mesajı,
        //   teslim edilmişse "İşi Bitir ve Sil" yönlendirmesi). Kabul edilmiş teklif İPTAL OLMAZ.
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var other = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var offer = await NewOffer(c, carrier, listing, 1000);
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");   // iş atandı

        var byOther = await Call(c, other, HttpMethod.Post, $"/api/v1/listings/{listing}/cancel");       // başkasının ilanı: 404
        var byCarrier = await Call(c, carrier, HttpMethod.Post, $"/api/v1/listings/{listing}/cancel");   // rol: 403
        var whileAssigned = await Call(c, shipper, HttpMethod.Post, $"/api/v1/listings/{listing}/cancel"); // teslim edilmedi: 409
        var assignedBody = await whileAssigned.Content.ReadAsStringAsync();
        await Deliver(c, carrier, offer);
        var afterDelivery = await Call(c, shipper, HttpMethod.Post, $"/api/v1/listings/{listing}/cancel");  // teslim edildi: yine 409 (İşi Bitir yolu)
        var deliveredBody = await afterDelivery.Content.ReadAsStringAsync();
        var carrierMine = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine"));

        var open = await NewListing(c, shipper);                                                          // açık ilan: kaldırılır, ikinci kez 409
        var openCancel = await Call(c, shipper, HttpMethod.Post, $"/api/v1/listings/{open}/cancel");
        var again = await Call(c, shipper, HttpMethod.Post, $"/api/v1/listings/{open}/cancel");

        await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/complete");
        var afterComplete = await Call(c, shipper, HttpMethod.Post, $"/api/v1/listings/{listing}/cancel");   // tamamlanmış iş iptal edilemez

        Assert.Equal(HttpStatusCode.NotFound, byOther.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, byCarrier.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, whileAssigned.StatusCode);
        Assert.Contains("teslim edilmeden", assignedBody);
        Assert.Equal(HttpStatusCode.Conflict, afterDelivery.StatusCode);
        Assert.Contains("İşi Bitir ve Sil", deliveredBody);
        Assert.Contains(carrierMine.EnumerateArray(), o => o.GetProperty("status").GetString() == "Accepted");   // kabul edilmiş teklif İPTAL OLMADI
        Assert.Equal(HttpStatusCode.NoContent, openCancel.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, afterComplete.StatusCode);
    }

    // ---------- araçlarım (15 Kasım) ----------
    private static async Task<string> NewCarrierWithoutVehicle(HttpClient c)
    {
        var n = Interlocked.Increment(ref _counter);
        var email = $"nv{n}@x.com";
        var reg = await c.PostAsJsonAsync("/api/v1/auth/register/carrier", new
        {
            fullName = $"Aracsiz {n}", email, phone = $"0533{1000000 + n}", password = "Abcdefg1", homeCityId = 33, kvkkAccepted = true, termsAccepted = true
        });
        Assert.Equal(HttpStatusCode.Created, reg.StatusCode); // kayıtta araç zorunlu değil
        var login = await c.PostAsJsonAsync("/api/v1/auth/login", new { emailOrPhone = email, password = "Abcdefg1", deviceId = "nv" + n, deviceName = "test" });
        return (await Json(login)).GetProperty("accessToken").GetString()!;
    }

    [Fact]
    public async Task A_carrier_without_a_vehicle_cannot_offer_until_one_is_added()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewCarrierWithoutVehicle(c);
        var listing = await NewListing(c, shipper);

        var before = await Call(c, carrier, HttpMethod.Post, $"/api/v1/listings/{listing}/offers", new { estimatedDeliveryDate = DateTime.UtcNow.AddDays(45).ToString("yyyy-MM-dd"), amount = 1000 });
        var beforeBody = await before.Content.ReadAsStringAsync();
        var add = await Call(c, carrier, HttpMethod.Post, "/api/v1/vehicles", new { type = "Truck", plateNumber = $"34 YK {Interlocked.Increment(ref _counter) % 90000 + 10000}", brand = "Ford", model = "Cargo", year = 2018 });
        var after = await Call(c, carrier, HttpMethod.Post, $"/api/v1/listings/{listing}/offers", new { estimatedDeliveryDate = DateTime.UtcNow.AddDays(45).ToString("yyyy-MM-dd"), amount = 1000 });

        Assert.Equal(HttpStatusCode.Conflict, before.StatusCode);
        Assert.Contains("Araçlarım", beforeBody);
        Assert.Equal(HttpStatusCode.Created, add.StatusCode);
        Assert.True(after.IsSuccessStatusCode); // araç eklendi → teklif kabul (teklif ucu 200 döner)
    }

    [Fact]
    public async Task Vehicles_can_be_listed_added_edited_and_deleted_with_plate_rules_and_ownership()
    {
        var c = await StartAsync();
        var carrier = await NewCarrierWithoutVehicle(c); var other = await NewCarrierWithoutVehicle(c); var shipper = await NewUser(c, true);
        var plate = $"06 TR {Interlocked.Increment(ref _counter) % 90000 + 10000}";

        var add = await Call(c, carrier, HttpMethod.Post, "/api/v1/vehicles", new { type = "Lorry", plateNumber = plate.ToLowerInvariant().Replace(" ", ""), capacityKg = 12000, brand = "Ford", model = "Cargo", year = 2018 });
        var added = await Json(add);
        var id = added.GetProperty("id").GetString();
        var noPlate = await Call(c, carrier, HttpMethod.Post, "/api/v1/vehicles", new { type = "Truck", brand = "Ford", model = "Cargo", year = 2018 });
        var badPlate = await Call(c, carrier, HttpMethod.Post, "/api/v1/vehicles", new { type = "Truck", plateNumber = "99 ZZ 1", brand = "Ford", model = "Cargo", year = 2018 });
        var duplicate = await Call(c, other, HttpMethod.Post, "/api/v1/vehicles", new { type = "Truck", plateNumber = plate, brand = "Ford", model = "Cargo", year = 2018 });
        var editByOther = await Call(c, other, HttpMethod.Put, $"/api/v1/vehicles/{id}", new { type = "Truck", plateNumber = plate, brand = "Ford", model = "Cargo", year = 2018 });
        var byShipper = await Call(c, shipper, HttpMethod.Get, "/api/v1/vehicles");
        var edit = await Call(c, carrier, HttpMethod.Put, $"/api/v1/vehicles/{id}", new { type = "Refrigerated", plateNumber = plate, brand = "Ford", model = "Cargo", year = 2018 });
        var list = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/vehicles"));
        var otherList = await Json(await Call(c, other, HttpMethod.Get, "/api/v1/vehicles"));
        var delete = await Call(c, carrier, HttpMethod.Delete, $"/api/v1/vehicles/{id}");
        var afterDelete = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/vehicles"));

        Assert.Equal(HttpStatusCode.Created, add.StatusCode);
        Assert.Equal(plate, added.GetProperty("plateNumber").GetString());              // tek biçime çevrildi ("06 TR 12345")
        Assert.Equal(HttpStatusCode.BadRequest, noPlate.StatusCode);                     // plaka zorunlu
        Assert.Equal(HttpStatusCode.BadRequest, badPlate.StatusCode);                    // biçim
        Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);                     // aynı plaka iki kez yok
        Assert.Equal(HttpStatusCode.NotFound, editByOther.StatusCode);                   // başkasının aracı
        Assert.Equal(HttpStatusCode.Forbidden, byShipper.StatusCode);                    // yalnız Taşımacı
        Assert.Equal(HttpStatusCode.OK, edit.StatusCode);
        Assert.Equal("Refrigerated", list[0].GetProperty("type").GetString());
        Assert.Equal(JsonValueKind.Null, list[0].GetProperty("capacityKg").ValueKind);   // kapasite isteğe bağlı (düzenlemede verilmedi)
        Assert.Equal(0, otherList.GetArrayLength());
        Assert.Equal(HttpStatusCode.NoContent, delete.StatusCode);
        Assert.Equal(0, afterDelete.GetArrayLength());
    }

    // ---------- karşılıklı iptal (15 Kasım) ----------
    private static async Task<string[]> NotificationTypes(HttpClient c, string token) =>
        (await Json(await Call(c, token, HttpMethod.Get, "/api/v1/notifications"))).GetProperty("items").EnumerateArray()
            .Select(n => n.GetProperty("type").ToString()).ToArray();

    [Fact]
    public async Task Carrier_requests_cancel_shipper_approves_and_republishes_the_listing()
    {
        // SENARYO: teklif kabul edildi, araç bozuldu. Taşımacı iptal ister, Yük Veren onaylar ve ilanı yeniden yayınlar.
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var offer = await NewOffer(c, carrier, listing, 1000);
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");

        var request = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/cancel-request", new { reason = "Araç arızası", note = "Motor arıza verdi" });
        var twice = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/cancel-request", new { reason = "Araç arızası" });
        var ownApprove = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/cancel-request/approve");
        var carrierView = (await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine")))[0].GetProperty("cancelRequest");
        var shipperView = (await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/offers/history")))[0].GetProperty("cancelRequest");
        var shipperTypes = await NotificationTypes(c, shipper);

        var approve = await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/cancel-request/approve", new { reopenListing = true });
        var carrierOffer = (await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine")))[0];
        var mine = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/listings/mine"));

        Assert.Equal(HttpStatusCode.NoContent, request.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, twice.StatusCode);                       // tek açık talep
        Assert.Equal(HttpStatusCode.Conflict, ownApprove.StatusCode);                  // kendi talebini onaylayamaz
        Assert.True(carrierView.GetProperty("byMe").GetBoolean());
        Assert.False(shipperView.GetProperty("byMe").GetBoolean());
        Assert.Equal("Araç arızası", shipperView.GetProperty("reason").GetString());
        Assert.Equal("Motor arıza verdi", shipperView.GetProperty("note").GetString());
        Assert.Contains("CancelRequested", shipperTypes);
        Assert.Equal(HttpStatusCode.NoContent, approve.StatusCode);
        Assert.Equal("Cancelled", carrierOffer.GetProperty("status").GetString());
        Assert.True(carrierOffer.GetProperty("mutuallyCancelled").GetBoolean());
        Assert.Equal(JsonValueKind.Null, carrierOffer.GetProperty("cancelRequest").ValueKind); // talep kapandı
        Assert.Contains(mine.EnumerateArray(), l => l.GetProperty("id").GetString() == listing); // ilan yeniden yayında
        Assert.Contains("CancelApproved", await NotificationTypes(c, carrier));
    }

    [Fact]
    public async Task After_mutual_cancel_the_republished_listing_reaches_the_same_carrier_who_can_offer_again()
    {
        // 15 Kasım (kullanıcı: "karşılıklı iptalden sonra aynı taşıyıcıya ilan tekrar düşmüyor"): yeniden yayınlanan ilan aynı Taşımacı'nın
        // açık listesine döner; yeni teklif YENİ kayıt olur, eski teklif geçmişte "Karşılıklı iptal" olarak kalır.
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var first = await NewOffer(c, carrier, listing, 1000);
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{first}/accept");
        await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{first}/cancel-request", new { reason = "Araç arızası" });
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{first}/cancel-request/approve", new { reopenListing = true })).StatusCode);

        var open = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings?page=1&pageSize=50"));
        Assert.Contains(open.GetProperty("items").EnumerateArray(), l => l.GetProperty("id").GetString() == listing);

        var second = await NewOffer(c, carrier, listing, 1200);
        Assert.NotEqual(first, second);
        var mine = (await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine"))).EnumerateArray().ToList();
        Assert.Equal("Cancelled", mine.Single(o => o.GetProperty("id").GetString() == first).GetProperty("status").GetString());
        Assert.Equal("Pending", mine.Single(o => o.GetProperty("id").GetString() == second).GetProperty("status").GetString());
        Assert.Equal(HttpStatusCode.OK, (await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{second}/accept")).StatusCode); // yeni teklif kabul edilebilir

        // Yeni teklif açıkken listeden yine düşer (yalnız karşılıklı iptal istisnadır)
        var again = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings?page=1&pageSize=50"));
        Assert.DoesNotContain(again.GetProperty("items").EnumerateArray(), l => l.GetProperty("id").GetString() == listing);
    }

    [Fact]
    public async Task Any_vehicle_listings_show_under_every_vehicle_filter_and_a_car_can_be_registered_but_any_cannot()
    {
        // 15 Kasım: ilanda "Farketmez" (Any), araçta "Otomobil" (Car)
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var any = await NewListingWith(c, shipper, "Küçük paket", 33, 34, 500, "Any", 10);
        var truckOnly = await NewListingWith(c, shipper, "Tır yükü", 33, 34, 5000, "Truck", 10);

        var pickup = (await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings?vehicleType=Pickup&page=1&pageSize=50")))
            .GetProperty("items").EnumerateArray().Select(l => l.GetProperty("id").GetString()).ToList();
        Assert.Contains(any, pickup);
        Assert.DoesNotContain(truckOnly, pickup);

        Assert.Equal(HttpStatusCode.Created, (await Call(c, carrier, HttpMethod.Post, "/api/v1/vehicles", new { type = "Car", plateNumber = "34 ZZ 1234", brand = "Fiat", model = "Egea", year = 2021 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Call(c, carrier, HttpMethod.Post, "/api/v1/vehicles", new { type = "Any", plateNumber = "34 ZZ 1235", brand = "Fiat", model = "Egea", year = 2021 })).StatusCode);
    }

    // ─── 15 Kasım: teklifte araç + teslim tarihi, araç bilgileri, Taşımacı sıralama/eşleşme ───

    private static string Day(int days) => DateTime.UtcNow.AddDays(days).ToString("yyyy-MM-dd");

    [Fact]
    public async Task An_offer_carries_the_chosen_vehicle_and_delivery_date_to_the_shipper()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false); // kayıttan bir Tır (Mercedes-Benz Actros 2019)
        var listing = await NewListing(c, shipper);                                    // yükleme +30 gün

        // Tarih yok → 400 | yüklemeden önce → 400 | 90 günden sonra → 400
        Assert.Equal(HttpStatusCode.BadRequest, (await Call(c, carrier, HttpMethod.Post, $"/api/v1/listings/{listing}/offers", new { amount = 1000 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Call(c, carrier, HttpMethod.Post, $"/api/v1/listings/{listing}/offers", new { amount = 1000, estimatedDeliveryDate = Day(10) })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Call(c, carrier, HttpMethod.Post, $"/api/v1/listings/{listing}/offers", new { amount = 1000, estimatedDeliveryDate = Day(130) })).StatusCode);

        // İkinci araç (Otomobil) eklenince seçim zorunlu olur; seçilen araç teklife kopyalanır
        var car = await Call(c, carrier, HttpMethod.Post, "/api/v1/vehicles", new { type = "Car", plateNumber = "34 YK 2026", brand = "Renault", model = "Clio", year = 2022 });
        var carId = (await Json(car)).GetProperty("id").GetString();
        Assert.Equal(HttpStatusCode.BadRequest, (await Call(c, carrier, HttpMethod.Post, $"/api/v1/listings/{listing}/offers", new { amount = 1000, estimatedDeliveryDate = Day(32) })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await Call(c, carrier, HttpMethod.Post, $"/api/v1/listings/{listing}/offers", new { amount = 1000, estimatedDeliveryDate = Day(32), vehicleId = carId })).StatusCode);

        var offer = (await Json(await Call(c, shipper, HttpMethod.Get, $"/api/v1/listings/{listing}/offers")))[0];
        Assert.Equal("Car", offer.GetProperty("vehicleType").GetString());
        Assert.Equal("Renault", offer.GetProperty("vehicleBrand").GetString());
        Assert.Equal(2022, offer.GetProperty("vehicleYear").GetInt32());
        Assert.Equal(Day(32), offer.GetProperty("estimatedDeliveryDate").GetString());
    }

    [Fact]
    public async Task Vehicle_brand_model_and_year_are_required_and_the_carrier_profile_lists_vehicles_without_plates()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var missing = await Call(c, carrier, HttpMethod.Post, "/api/v1/vehicles", new { type = "Pickup", plateNumber = "06 AB 123" });
        Assert.Equal(HttpStatusCode.BadRequest, missing.StatusCode);
        var errors = (await Json(missing)).GetProperty("errors");
        var keys = errors.EnumerateObject().Select(p => p.Name.ToLowerInvariant()).ToList(); // anahtar yazımı (camelCase) API kuralına bırakılır
        Assert.Contains("brand", keys); Assert.Contains("model", keys); Assert.Contains("year", keys);
        Assert.Equal(HttpStatusCode.BadRequest, (await Call(c, carrier, HttpMethod.Post, "/api/v1/vehicles", new { type = "Pickup", plateNumber = "06 AB 123", brand = "Ford", model = "Transit", year = 1900 })).StatusCode);

        var listing = await NewListing(c, shipper);
        await NewOffer(c, carrier, listing);
        var cid = (await Json(await Call(c, shipper, HttpMethod.Get, $"/api/v1/listings/{listing}/offers")))[0].GetProperty("carrierId").GetString();
        var raw = await (await Call(c, shipper, HttpMethod.Get, $"/api/v1/carriers/{cid}")).Content.ReadAsStringAsync();
        var vehicles = JsonDocument.Parse(raw).RootElement.GetProperty("vehicles");
        Assert.Equal("Mercedes-Benz", vehicles[0].GetProperty("brand").GetString());
        Assert.Equal(2019, vehicles[0].GetProperty("year").GetInt32());
        Assert.DoesNotContain("33 ABC 123", raw); // plaka profilde yok
    }

    [Fact]
    public async Task Carrier_can_sort_by_pickup_date_and_see_only_listings_matching_own_vehicles()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false); // yalnız Tır
        var late = await NewListingWith(c, shipper, "Geç", 33, 34, 1000, "Truck", 40);
        var soon = await NewListingWith(c, shipper, "Yakın", 33, 34, 1000, "Truck", 5);
        var cold = await NewListingWith(c, shipper, "Soğuk", 33, 34, 1000, "Refrigerated", 10);
        var any = await NewListingWith(c, shipper, "Farketmez", 33, 34, 1000, "Any", 20);

        var sorted = (await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings?sort=PickupSoonest&page=1&pageSize=50")))
            .GetProperty("items").EnumerateArray().Select(l => l.GetProperty("id").GetString()).ToList();
        Assert.Equal([soon, cold, any, late], sorted);

        var mine = (await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings?matchMyVehicles=true&page=1&pageSize=50")))
            .GetProperty("items").EnumerateArray().Select(l => l.GetProperty("id").GetString()).ToList();
        Assert.Contains(soon, mine); Assert.Contains(late, mine); Assert.Contains(any, mine);
        Assert.DoesNotContain(cold, mine); // frigorifik aracı yok
    }

    [Fact]
    public async Task Distance_weight_and_price_filters_work_together()
    {
        // 15 Kasım (sahibinden tarzı): "Mersin'e 100 km içinde + 1.000–10.000 ₺ + en çok 5 ton" aynı anda
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var mersinCheap = await NewListingWith(c, shipper, "Mersin ucuz", 33, 34, 3000, "Truck", 10);   // 1000 kg (yardımcı)
        var mersinExpensive = await NewListingWith(c, shipper, "Mersin pahalı", 33, 34, 50000, "Truck", 10);
        var istanbul = await NewListingWith(c, shipper, "İstanbul", 34, 33, 3000, "Truck", 10);

        const string me = "lat=36.8&lon=34.6"; // Mersin
        var ids = async (string q) => (await Json(await Call(c, carrier, HttpMethod.Get, $"/api/v1/listings?{q}&page=1&pageSize=50")))
            .GetProperty("items").EnumerateArray().Select(l => l.GetProperty("id").GetString()).ToList();

        var near = await ids($"{me}&maxDistanceKm=100&sort=Newest");
        Assert.Contains(mersinCheap, near); Assert.Contains(mersinExpensive, near); Assert.DoesNotContain(istanbul, near);

        var combined = await ids($"{me}&maxDistanceKm=100&minBudget=1000&maxBudget=10000&maxWeightKg=5000");
        Assert.Equal([mersinCheap], combined);

        Assert.Empty(await ids("minWeightKg=2000")); // hepsi 1000 kg
        Assert.Equal(HttpStatusCode.BadRequest, (await Call(c, carrier, HttpMethod.Get, "/api/v1/listings?maxDistanceKm=50")).StatusCode); // konumsuz uzaklık
    }

    [Fact]
    public async Task A_pending_offer_with_messages_is_marked_as_being_discussed()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var quiet = await NewOffer(c, carrier, await NewListing(c, shipper));
        var talked = await NewOffer(c, carrier, await NewListing(c, shipper));
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{talked}/messages", new { text = "Yarın yükleyebilir misin?" });

        var mine = (await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine"))).EnumerateArray().ToList();
        Assert.True(mine.Single(o => o.GetProperty("id").GetString() == talked).GetProperty("hasMessages").GetBoolean());
        Assert.False(mine.Single(o => o.GetProperty("id").GetString() == quiet).GetProperty("hasMessages").GetBoolean());
    }

    [Fact]
    public async Task Shipper_requests_cancel_carrier_rejects_then_approves_and_the_listing_is_removed_as_the_shipper_chose()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var offer = await NewOffer(c, carrier, listing, 1000);
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");

        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/cancel-request", new { reason = "Yük hazır değil", reopenListing = false });
        var reject = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/cancel-request/reject");
        var afterReject = (await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine")))[0];
        var shipperTypes = await NotificationTypes(c, shipper);

        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/cancel-request", new { reason = "Yük hazır değil", reopenListing = false });
        var approve = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/cancel-request/approve");
        var mine = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/listings/mine"));

        Assert.Equal(HttpStatusCode.NoContent, reject.StatusCode);
        Assert.Equal("Accepted", afterReject.GetProperty("status").GetString());     // reddedildi: iş sürüyor
        Assert.Equal(JsonValueKind.Null, afterReject.GetProperty("cancelRequest").ValueKind);
        Assert.Contains("CancelRejected", shipperTypes);
        Assert.Equal(HttpStatusCode.NoContent, approve.StatusCode);
        Assert.DoesNotContain(mine.EnumerateArray(), l => l.GetProperty("id").GetString() == listing); // Yük Veren "kaldır" seçmişti
    }

    [Fact]
    public async Task Cancel_requests_need_an_active_undelivered_job_a_party_and_a_reason_and_can_be_withdrawn_only_by_the_requester()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false); var outsider = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var offer = await NewOffer(c, carrier, listing, 1000);

        var onPending = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/cancel-request", new { reason = "Araç arızası" });
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");
        var byOutsider = await Call(c, outsider, HttpMethod.Post, $"/api/v1/offers/{offer}/cancel-request", new { reason = "Araç arızası" });
        var noReason = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/cancel-request", new { reason = " " });
        await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/cancel-request", new { reason = "Araç arızası" });
        var withdrawByOther = await Call(c, shipper, HttpMethod.Delete, $"/api/v1/offers/{offer}/cancel-request");
        var withdraw = await Call(c, carrier, HttpMethod.Delete, $"/api/v1/offers/{offer}/cancel-request");
        var approveNothing = await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/cancel-request/approve");
        await Deliver(c, carrier, offer);
        var afterDelivery = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/cancel-request", new { reason = "Araç arızası" });

        Assert.Equal(HttpStatusCode.Conflict, onPending.StatusCode);       // kabul edilmemiş teklif
        Assert.Equal(HttpStatusCode.NotFound, byOutsider.StatusCode);      // taraf değil
        Assert.Equal(HttpStatusCode.BadRequest, noReason.StatusCode);      // neden zorunlu
        Assert.Equal(HttpStatusCode.Conflict, withdrawByOther.StatusCode); // yalnız talep eden geri çeker
        Assert.Equal(HttpStatusCode.NoContent, withdraw.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, approveNothing.StatusCode);  // açık talep yok
        Assert.Equal(HttpStatusCode.Conflict, afterDelivery.StatusCode);   // teslimden sonra "İşi Bitir"
    }

    // ---------- ilan listesi: filtre, sıralama, sayfalama ----------
    private static async Task<string> NewListingWith(HttpClient c, string shipperToken, string title, int fromCityId, int toCityId,
        decimal? budget, string vehicleType, int daysAhead)
    {
        var from = (await Json(await c.GetAsync($"/api/v1/cities/{fromCityId}/districts")))[0].GetProperty("id").GetInt32();
        var to = (await Json(await c.GetAsync($"/api/v1/cities/{toCityId}/districts")))[0].GetProperty("id").GetInt32();
        var r = await Call(c, shipperToken, HttpMethod.Post, "/api/v1/listings", new
        {
            title, weightKg = 1000, vehicleType, fromCityId, fromDistrictId = from, toCityId, toDistrictId = to,
            pickupDate = DateTime.UtcNow.AddDays(daysAhead).ToString("yyyy-MM-dd"), budget
        });
        Assert.Equal(HttpStatusCode.Created, r.StatusCode);
        return (await Json(r)).GetProperty("id").GetString()!;
    }

    private static string[] Titles(JsonElement items) => items.EnumerateArray().Select(i => i.GetProperty("title").GetString()!).ToArray();

    // 4 ilan: A Mersin→İstanbul 1000 Truck +5g | B Mersin→Ankara 3000 Lorry +20g | C Adana→İstanbul 5000 Truck +40g | D Mersin→İstanbul bütçesiz Pickup +10g
    private async Task<(HttpClient C, string Shipper, string Carrier)> FourListings()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        await NewListingWith(c, shipper, "A", 33, 34, 1000, "Truck", 5);
        await NewListingWith(c, shipper, "B", 33, 6, 3000, "Lorry", 20);
        await NewListingWith(c, shipper, "C", 1, 34, 5000, "Truck", 40);
        await NewListingWith(c, shipper, "D", 33, 34, null, "Pickup", 10);
        return (c, shipper, carrier);
    }

    [Fact]
    public async Task The_open_list_filters_by_destination_price_vehicle_and_date_and_reports_the_total()
    {
        var (c, _, carrier) = await FourListings();
        async Task<string> Get(string query)
        {
            var json = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings?" + query));
            return $"{string.Join(",", Titles(json.GetProperty("items")).Order())}|{json.GetProperty("totalCount").GetInt32()}"; // "A,C,D|3" = başlıklar|toplam
        }
        var day = (int d) => DateTime.UtcNow.AddDays(d).ToString("yyyy-MM-dd");

        Assert.Equal("A,C,D|3", await Get("toCityId=34"));
        Assert.Equal("B,C|2", await Get("minBudget=2000"));                    // bütçesiz D fiyat aralığına girmez
        Assert.Equal("A,B|2", await Get("maxBudget=3000"));
        Assert.Equal("B|1", await Get("minBudget=2000&maxBudget=3000"));
        Assert.Equal("A,C|2", await Get("vehicleType=Truck"));
        Assert.Equal("B,D|2", await Get($"pickupFrom={day(8)}&pickupTo={day(25)}"));
        Assert.Equal("A|1", await Get("fromCityId=33&toCityId=34&vehicleType=Truck"));   // filtreler birlikte (AND)
        Assert.Equal("A,B,C,D|4", await Get(""));                         // filtre yok: hepsi
        Assert.Equal("|0", await Get("toCityId=6&vehicleType=Truck"));    // eşleşme yok: boş sayfa, toplam 0
    }

    [Fact]
    public async Task The_open_list_sorts_by_newest_and_by_price_with_unpriced_listings_last()
    {
        var (c, _, carrier) = await FourListings();
        async Task<string[]> Order(string query) =>
            Titles((await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings?" + query))).GetProperty("items"));

        Assert.Equal(new[] { "D", "C", "B", "A" }, await Order(""));                         // varsayılan: en yeni üstte
        Assert.Equal(new[] { "D", "C", "B", "A" }, await Order("sort=Newest"));
        Assert.Equal(new[] { "A", "B", "C", "D" }, await Order("sort=PriceAsc"));            // bütçesiz D en sonda
        Assert.Equal(new[] { "C", "B", "A", "D" }, await Order("sort=PriceDesc"));           // azalanda da D en sonda
    }

    [Fact]
    public async Task The_open_list_pages_without_repeating_or_losing_listings_even_when_prices_tie()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        for (var i = 1; i <= 5; i++) await NewListingWith(c, shipper, $"L{i}", 33, 34, 2000, "Truck", 5);   // beşinin de fiyatı aynı

        async Task<(string[] Titles, int Total, int PageNo, int Size)> Page(int page)
        {
            var json = await Json(await Call(c, carrier, HttpMethod.Get, $"/api/v1/listings?sort=PriceAsc&pageSize=2&page={page}"));
            return (Titles(json.GetProperty("items")), json.GetProperty("totalCount").GetInt32(),
                json.GetProperty("page").GetInt32(), json.GetProperty("pageSize").GetInt32());
        }
        var p1 = await Page(1); var p2 = await Page(2); var p3 = await Page(3); var p4 = await Page(4);

        Assert.Equal(2, p1.Titles.Length); Assert.Equal(2, p2.Titles.Length); Assert.Single(p3.Titles); Assert.Empty(p4.Titles);
        Assert.All(new[] { p1, p2, p3, p4 }, p => Assert.Equal(5, p.Total));                 // toplam her sayfada aynı
        Assert.Equal((1, 2), (p1.PageNo, p1.Size));
        var all = p1.Titles.Concat(p2.Titles).Concat(p3.Titles).ToArray();
        Assert.Equal(5, all.Distinct().Count());                                              // kararlı sıra: tekrar yok, kayıp yok
        Assert.Equal(await Titles2(c, carrier, "sort=PriceAsc&pageSize=50"), all);            // sayfalar birleşince tek büyük sayfayla aynı sıra
    }

    private static async Task<string[]> Titles2(HttpClient c, string token, string query) =>
        Titles((await Json(await Call(c, token, HttpMethod.Get, "/api/v1/listings?" + query))).GetProperty("items"));

    [Fact]
    public async Task The_nearest_sort_is_paged_by_distance_and_reports_distance_on_each_item()
    {
        var (c, _, carrier) = await FourListings();      // A,B,D Mersin çıkışlı, C Adana çıkışlı

        var first = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings?lat=36.8&lon=34.6&pageSize=2"));
        var second = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings?lat=36.8&lon=34.6&pageSize=2&page=2"));

        Assert.Equal(4, first.GetProperty("totalCount").GetInt32());
        var near = Titles(first.GetProperty("items")); var far = Titles(second.GetProperty("items"));
        Assert.Equal(2, near.Length); Assert.Equal(2, far.Length);
        Assert.Equal("C", far.Last());                                                        // Adana en uzak: son sayfanın sonunda
        Assert.Equal(new[] { "A", "B", "D" }, near.Concat(far.Take(1)).Order().ToArray());    // Mersin'dekiler önce
        Assert.All(first.GetProperty("items").EnumerateArray(), i => Assert.True(i.GetProperty("distanceKm").GetDouble() < 5));
    }

    [Fact]
    public async Task The_open_list_rejects_bad_query_parameters_with_400_and_excludes_listings_already_offered_on()
    {
        var (c, shipper, carrier) = await FourListings();
        async Task<HttpStatusCode> Status(string query) => (await Call(c, carrier, HttpMethod.Get, "/api/v1/listings?" + query)).StatusCode;

        Assert.Equal(HttpStatusCode.BadRequest, await Status("page=0"));
        Assert.Equal(HttpStatusCode.BadRequest, await Status("pageSize=0"));
        Assert.Equal(HttpStatusCode.BadRequest, await Status("pageSize=51"));                 // en çok 50
        Assert.Equal(HttpStatusCode.BadRequest, await Status("minBudget=5000&maxBudget=1000"));
        Assert.Equal(HttpStatusCode.BadRequest, await Status("minBudget=-1"));
        Assert.Equal(HttpStatusCode.BadRequest, await Status("pickupFrom=2026-12-01&pickupTo=2026-11-01"));
        Assert.Equal(HttpStatusCode.BadRequest, await Status("sort=Nearest"));                // konumsuz en yakın
        Assert.Equal(HttpStatusCode.BadRequest, await Status("sort=Bogus"));
        Assert.Equal(HttpStatusCode.BadRequest, await Status("vehicleType=Spaceship"));
        Assert.Equal(HttpStatusCode.BadRequest, await Status("lat=36.8"));                    // lat tek başına
        Assert.Equal(HttpStatusCode.Forbidden, (await Call(c, shipper, HttpMethod.Get, "/api/v1/listings")).StatusCode);

        // teklif verilen ilan listeden ve toplamdan düşer
        var a = (await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/listings/mine"))).EnumerateArray().First(i => i.GetProperty("title").GetString() == "A").GetProperty("id").GetString()!;
        await NewOffer(c, carrier, a, 900);
        var json = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings"));
        Assert.Equal(3, json.GetProperty("totalCount").GetInt32());
        Assert.DoesNotContain("A", Titles(json.GetProperty("items")));
    }

    // ---------- ilan güncelle ----------
    private static async Task<object> UpdateBody(HttpClient c, string title = "Güncel ilan", decimal? budget = 7000, int weightKg = 2000)
    {
        var from = (await Json(await c.GetAsync("/api/v1/cities/35/districts")))[0].GetProperty("id").GetInt32();
        var to = (await Json(await c.GetAsync("/api/v1/cities/6/districts")))[0].GetProperty("id").GetInt32();
        return new
        {
            title, description = "Yeni açıklama", weightKg, vehicleType = "Lorry", fromCityId = 35, fromDistrictId = from, toCityId = 6, toDistrictId = to,
            pickupDate = DateTime.UtcNow.AddDays(10).ToString("yyyy-MM-dd"), budget
        };
    }

    [Fact]
    public async Task Updating_an_open_listing_changes_it_and_keeps_pending_offers()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var offer = await NewOffer(c, carrier, listing, 1000);

        var response = await Call(c, shipper, HttpMethod.Put, $"/api/v1/listings/{listing}", await UpdateBody(c));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var json = await Json(response);
        Assert.Equal("Güncel ilan", json.GetProperty("title").GetString());
        Assert.Equal(2000, json.GetProperty("weightKg").GetInt32());
        Assert.Equal(35, json.GetProperty("fromCityId").GetInt32());
        Assert.Equal(7000m, json.GetProperty("budget").GetDecimal());
        // liste de güncel; aynı sayıda ilan, bekleyen teklif durduğu yerde
        var mine = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/listings/mine"));
        Assert.Equal("Güncel ilan", mine.EnumerateArray().Single().GetProperty("title").GetString());
        var offers = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine"));
        Assert.Equal("Pending", offers.EnumerateArray().Single().GetProperty("status").GetString());
        Assert.Equal("Güncel ilan", offers.EnumerateArray().Single().GetProperty("listingTitle").GetString());
    }

    [Fact]
    public async Task Updating_a_listing_is_owner_only_and_returns_the_right_error_codes()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var other = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var body = await UpdateBody(c);

        var anonymous = await Call(c, null, HttpMethod.Put, $"/api/v1/listings/{listing}", body);
        var byCarrier = await Call(c, carrier, HttpMethod.Put, $"/api/v1/listings/{listing}", body);
        var byOther = await Call(c, other, HttpMethod.Put, $"/api/v1/listings/{listing}", body);
        var missing = await Call(c, shipper, HttpMethod.Put, $"/api/v1/listings/{Guid.NewGuid()}", body);
        var invalid = await Call(c, shipper, HttpMethod.Put, $"/api/v1/listings/{listing}", await UpdateBody(c, title: "", budget: 200_000_000m));

        Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, byCarrier.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, byOther.StatusCode);     // başkasının ilanı: varlığı sızdırılmaz
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
        // reddedilen isteklerden sonra ilan değişmedi
        var mine = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/listings/mine"));
        Assert.Equal("Test ilan", mine.EnumerateArray().Single().GetProperty("title").GetString());
    }

    [Fact]
    public async Task A_listing_cannot_be_updated_once_a_job_is_assigned_completed_or_removed()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var body = await UpdateBody(c);

        var assigned = await NewListing(c, shipper);
        var offer = await NewOffer(c, carrier, assigned, 1000);
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");
        var whileAssigned = await Call(c, shipper, HttpMethod.Put, $"/api/v1/listings/{assigned}", body);

        await Deliver(c, carrier, offer);
        await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/complete");
        var afterComplete = await Call(c, shipper, HttpMethod.Put, $"/api/v1/listings/{assigned}", body);

        var removed = await NewListing(c, shipper);
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/listings/{removed}/cancel");
        var afterRemove = await Call(c, shipper, HttpMethod.Put, $"/api/v1/listings/{removed}", body);

        Assert.Equal(HttpStatusCode.Conflict, whileAssigned.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, afterComplete.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, afterRemove.StatusCode);
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

    // ---------- teklifi geri çekme ----------
    [Fact]
    public async Task Withdraw_marks_the_pending_offer_withdrawn_and_hides_it_from_the_shipper()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var offer = await NewOffer(c, carrier, listing);

        var withdraw = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/withdraw");
        var shipperOffers = await Json(await Call(c, shipper, HttpMethod.Get, $"/api/v1/listings/{listing}/offers"));
        var shipperHistory = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/offers/history"));
        var mine = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine"));
        var unseen = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine/unseen-count"));

        Assert.Equal(HttpStatusCode.OK, withdraw.StatusCode);
        Assert.Equal(0, shipperOffers.GetArrayLength());                 // Yük Veren görmez
        Assert.Equal(0, shipperHistory.GetArrayLength());
        Assert.Equal(1, mine.GetArrayLength());                          // Taşımacı kendi geçmişinde görür
        Assert.Equal("Withdrawn", mine[0].GetProperty("status").GetString());
        Assert.False(mine[0].GetProperty("isNew").GetBoolean());         // kendi işlemi: "Yeni" rozeti yok
        Assert.Equal(0, unseen.GetProperty("count").GetInt32());
    }

    [Fact]
    public async Task Withdraw_is_only_for_the_owner_and_only_for_pending_offers()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false); var other = await NewUser(c, false);
        var offer = await NewOffer(c, carrier, await NewListing(c, shipper));

        var byOther = await Call(c, other, HttpMethod.Post, $"/api/v1/offers/{offer}/withdraw");      // başkasının teklifi: 404
        var byShipper = await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/withdraw");  // rol yanlış: 403
        var missing = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{Guid.NewGuid()}/withdraw");
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");
        var accepted = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/withdraw");   // kabul edilmiş: 409

        Assert.Equal(HttpStatusCode.NotFound, byOther.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, byShipper.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, accepted.StatusCode);
    }

    [Fact]
    public async Task A_withdrawn_offer_can_be_renewed_and_is_closed_for_chat_and_a_second_withdraw()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var offer = await NewOffer(c, carrier, listing, 1000);
        await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/withdraw");

        var chat = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/messages", new { text = "merhaba" });
        var again = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/withdraw");
        var renewed = await Call(c, carrier, HttpMethod.Post, $"/api/v1/listings/{listing}/offers", new { estimatedDeliveryDate = DateTime.UtcNow.AddDays(45).ToString("yyyy-MM-dd"), amount = 900, note = "yeniden" });
        var shipperOffers = await Json(await Call(c, shipper, HttpMethod.Get, $"/api/v1/listings/{listing}/offers"));

        Assert.Equal(HttpStatusCode.Conflict, chat.StatusCode);          // sohbet kapalı
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);         // ikinci geri çekme: bekleyen değil
        Assert.Equal(HttpStatusCode.OK, renewed.StatusCode);             // aynı ilana yeniden teklif serbest
        Assert.Equal(1, shipperOffers.GetArrayLength());                 // yeniden Beklemede, Yük Veren görür
        Assert.Equal(900m, shipperOffers[0].GetProperty("amount").GetDecimal());
    }

    // ---------- iş aşamaları ----------
    [Fact]
    public async Task The_carrier_advances_an_accepted_job_one_stage_at_a_time_and_both_sides_see_it()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var offer = await NewOffer(c, carrier, await NewListing(c, shipper));
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");

        var stages = new List<string>();
        for (var i = 0; i < 3; i++)
            stages.Add((await Json(await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/advance"))).GetProperty("stage").GetString()!);
        var fourth = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/advance");
        var carrierMine = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine"));
        var shipperHistory = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/offers/history"));

        Assert.Equal(new[] { "PickedUp", "InTransit", "Delivered" }, stages);
        Assert.Equal(HttpStatusCode.Conflict, fourth.StatusCode);                                  // teslimden sonra ilerlemez
        Assert.Equal("Delivered", carrierMine[0].GetProperty("stage").GetString());
        Assert.Equal("Delivered", shipperHistory[0].GetProperty("stage").GetString());              // Yük Veren de izler
    }

    [Fact]
    public async Task Advancing_is_only_for_the_owner_carrier_and_only_for_an_accepted_job()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false); var other = await NewUser(c, false);
        var offer = await NewOffer(c, carrier, await NewListing(c, shipper));

        var pending = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/advance");      // kabul edilmemiş: 409
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");
        var byOther = await Call(c, other, HttpMethod.Post, $"/api/v1/offers/{offer}/advance");        // başkası: 404
        var byShipper = await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/advance");    // rol: 403
        var missing = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{Guid.NewGuid()}/advance");

        Assert.Equal(HttpStatusCode.Conflict, pending.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, byOther.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, byShipper.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
    }

    // ---------- puan ve yorum, Taşımacı profili ----------
    // Bir işi baştan sona yürütür (teklif → kabul → teslim → Taşımacı tamamlar) ve (teklif numarası, Taşımacı numarası) döner.
    private async Task<(string Offer, string CarrierId)> CompletedJob(HttpClient c, string shipper, string carrier, decimal amount = 1000)
    {
        var listing = await NewListing(c, shipper);
        var offer = await NewOffer(c, carrier, listing, amount);
        var carrierId = (await Json(await Call(c, shipper, HttpMethod.Get, $"/api/v1/listings/{listing}/offers")))[0].GetProperty("carrierId").GetString()!;
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");
        await Deliver(c, carrier, offer);
        Assert.Equal(HttpStatusCode.OK, (await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/complete")).StatusCode);
        return (offer, carrierId);
    }

    [Fact]
    public async Task Reviews_update_the_carrier_average_count_and_completed_jobs_and_show_on_the_profile()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var (first, carrierId) = await CompletedJob(c, shipper, carrier);
        var (second, _) = await CompletedJob(c, shipper, carrier);

        var r1 = await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{first}/review", new { rating = 5, comment = "Harika" });
        var r2 = await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{second}/review", new { rating = 2, comment = (string?)null });
        var profile = await Json(await Call(c, shipper, HttpMethod.Get, $"/api/v1/carriers/{carrierId}"));
        var asCarrier = await Call(c, carrier, HttpMethod.Get, $"/api/v1/carriers/{carrierId}");   // Taşımacı da kendi profilini görür

        Assert.Equal(HttpStatusCode.Created, r1.StatusCode);
        Assert.Equal(HttpStatusCode.Created, r2.StatusCode);
        Assert.Equal(3.5m, profile.GetProperty("averageRating").GetDecimal());       // (5 + 2) / 2
        Assert.Equal(2, profile.GetProperty("ratingCount").GetInt32());
        Assert.Equal(2, profile.GetProperty("completedJobCount").GetInt32());
        var reviews = profile.GetProperty("reviews");
        Assert.Equal(2, reviews.GetArrayLength());
        Assert.Contains(reviews.EnumerateArray(), x => x.GetProperty("comment").GetString() == "Harika");
        Assert.Matches(@"^\S+ \S\.$", reviews[0].GetProperty("shipperName").GetString()!);   // "Ad S." biçimi: soyad kısaltılmış
        Assert.Equal(HttpStatusCode.OK, asCarrier.StatusCode);
    }

    [Fact]
    public async Task A_review_needs_a_completed_job_from_the_owner_with_a_valid_rating_and_only_once()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var other = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var offer = await NewOffer(c, carrier, listing);
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");
        var url = $"/api/v1/offers/{offer}/review";

        var notCompleted = await Call(c, shipper, HttpMethod.Post, url, new { rating = 5 });           // tamamlanmadı: 409
        await Deliver(c, carrier, offer);
        await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/complete");
        var byOther = await Call(c, other, HttpMethod.Post, url, new { rating = 5 });                  // başkasının işi: 404
        var byCarrier = await Call(c, carrier, HttpMethod.Post, url, new { rating = 5 });              // rol: 403
        var zero = await Call(c, shipper, HttpMethod.Post, url, new { rating = 0 });                   // 400
        var six = await Call(c, shipper, HttpMethod.Post, url, new { rating = 6 });                    // 400
        var longComment = await Call(c, shipper, HttpMethod.Post, url, new { rating = 4, comment = new string('x', 501) });   // 400
        var ok = await Call(c, shipper, HttpMethod.Post, url, new { rating = 4 });
        var twice = await Call(c, shipper, HttpMethod.Post, url, new { rating = 5 });                  // ikinci puan: 409
        var history = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/offers/history"));    // Taşımacı bitirdi: Yük Veren'de durur

        Assert.Equal(HttpStatusCode.Conflict, notCompleted.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, byOther.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, byCarrier.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, zero.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, six.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, longComment.StatusCode);
        Assert.Equal(HttpStatusCode.Created, ok.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, twice.StatusCode);
        Assert.True(history[0].GetProperty("reviewed").GetBoolean());   // iOS "Puan ver" düğmesini gizlesin
    }

    [Fact]
    public async Task The_carrier_profile_is_404_for_unknown_ids_and_shows_the_rating_next_to_each_offer()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var (offer, carrierId) = await CompletedJob(c, shipper, carrier);
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/review", new { rating = 4 });

        var unknown = await Call(c, shipper, HttpMethod.Get, $"/api/v1/carriers/{Guid.NewGuid()}");
        var anonymous = await Call(c, null, HttpMethod.Get, $"/api/v1/carriers/{carrierId}");
        var listing = await NewListing(c, shipper);
        await NewOffer(c, carrier, listing);
        var offers = await Json(await Call(c, shipper, HttpMethod.Get, $"/api/v1/listings/{listing}/offers"));

        Assert.Equal(HttpStatusCode.NotFound, unknown.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);
        Assert.Equal(4m, offers[0].GetProperty("carrierRating").GetDecimal());          // Yük Veren, teklif listesinde puanı görür
        Assert.Equal(1, offers[0].GetProperty("carrierRatingCount").GetInt32());
        Assert.Equal(carrierId, offers[0].GetProperty("carrierId").GetString());
    }

    // ---------- emsal fiyat ----------
    [Fact]
    public async Task Price_reference_is_the_median_of_completed_jobs_on_the_same_route_and_needs_three_of_them()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        const string url = "/api/v1/price-reference?fromCityId=33&toCityId=34&vehicleType=Truck";

        await CompletedJob(c, shipper, carrier, 1000);
        await CompletedJob(c, shipper, carrier, 4000);
        var twoJobs = await Json(await Call(c, carrier, HttpMethod.Get, url));          // 2 iş: gösterilmez

        await CompletedJob(c, shipper, carrier, 2000);
        var threeJobs = await Json(await Call(c, carrier, HttpMethod.Get, url));        // 3 iş: medyan 2000

        var otherRoute = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/price-reference?fromCityId=6&toCityId=34&vehicleType=Truck"));
        var otherVehicle = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/price-reference?fromCityId=33&toCityId=34&vehicleType=Lorry"));

        Assert.Equal(JsonValueKind.Null, twoJobs.GetProperty("medianAmount").ValueKind);
        Assert.Equal(2, twoJobs.GetProperty("sampleCount").GetInt32());
        Assert.Equal(2000m, threeJobs.GetProperty("medianAmount").GetDecimal());
        Assert.Equal(3, threeJobs.GetProperty("sampleCount").GetInt32());
        Assert.Equal(0, otherRoute.GetProperty("sampleCount").GetInt32());              // başka rota karışmaz
        Assert.Equal(0, otherVehicle.GetProperty("sampleCount").GetInt32());            // başka araç tipi karışmaz
    }

    [Fact]
    public async Task Price_reference_ignores_jobs_that_are_not_completed_and_validates_its_parameters()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        for (var i = 0; i < 3; i++)   // 3 teklif kabul edildi ama TAMAMLANMADI
        {
            var offer = await NewOffer(c, carrier, await NewListing(c, shipper), 1000 + i);
            await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");
        }
        const string url = "/api/v1/price-reference?fromCityId=33&toCityId=34&vehicleType=Truck";

        var result = await Json(await Call(c, carrier, HttpMethod.Get, url));
        var anonymous = await Call(c, null, HttpMethod.Get, url);
        var missing = await Call(c, carrier, HttpMethod.Get, "/api/v1/price-reference");
        var badCity = await Call(c, carrier, HttpMethod.Get, "/api/v1/price-reference?fromCityId=0&toCityId=34&vehicleType=Truck");

        Assert.Equal(0, result.GetProperty("sampleCount").GetInt32());
        Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, missing.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, badCity.StatusCode);
    }

    // ---------- favoriler ve sayaçlar ----------
    [Fact]
    public async Task Favoriting_is_idempotent_shows_in_the_open_list_and_in_the_favorites_list()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var url = $"/api/v1/listings/{listing}/favorite";

        var first = await Call(c, carrier, HttpMethod.Put, url);
        var second = await Call(c, carrier, HttpMethod.Put, url);                                   // iki kez: hata yok, sayı şişmez
        var open = await Items(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings"));
        var favorites = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings/favorites"));
        var stats = await Json(await Call(c, shipper, HttpMethod.Get, $"/api/v1/listings/{listing}/stats"));

        Assert.Equal(HttpStatusCode.NoContent, first.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, second.StatusCode);
        Assert.True(open[0].GetProperty("isFavorite").GetBoolean());                                 // kalp dolu
        Assert.Equal(1, favorites.GetArrayLength());
        Assert.True(favorites[0].GetProperty("isFavorite").GetBoolean());
        Assert.Equal(1, stats.GetProperty("favoriteCount").GetInt32());

        var remove1 = await Call(c, carrier, HttpMethod.Delete, url);
        var remove2 = await Call(c, carrier, HttpMethod.Delete, url);                               // favori değilken çıkar: hata yok
        var after = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings/favorites"));
        var openAfter = await Items(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings"));

        Assert.Equal(HttpStatusCode.NoContent, remove1.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, remove2.StatusCode);
        Assert.Equal(0, after.GetArrayLength());
        Assert.False(openAfter[0].GetProperty("isFavorite").GetBoolean());
    }

    [Fact]
    public async Task Favorites_are_per_carrier_carrier_only_and_drop_listings_that_are_no_longer_open()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var a = await NewUser(c, false); var b = await NewUser(c, false);
        var listing = await NewListing(c, shipper);

        await Call(c, a, HttpMethod.Put, $"/api/v1/listings/{listing}/favorite");
        var byShipper = await Call(c, shipper, HttpMethod.Put, $"/api/v1/listings/{listing}/favorite");   // rol: 403
        var unknown = await Call(c, a, HttpMethod.Put, $"/api/v1/listings/{Guid.NewGuid()}/favorite");    // 404
        var bList = await Json(await Call(c, b, HttpMethod.Get, "/api/v1/listings/favorites"));            // b'nin listesi boş
        await Call(c, shipper, HttpMethod.Post, $"/api/v1/listings/{listing}/cancel");                      // ilan kaldırıldı
        var aList = await Json(await Call(c, a, HttpMethod.Get, "/api/v1/listings/favorites"));

        Assert.Equal(HttpStatusCode.Forbidden, byShipper.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, unknown.StatusCode);
        Assert.Equal(0, bList.GetArrayLength());
        Assert.Equal(0, aList.GetArrayLength());                                                           // kaldırılan ilan favoriden düştü
    }

    [Fact]
    public async Task Views_count_each_carrier_once_per_day_and_stats_are_owner_only()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var other = await NewUser(c, true); var a = await NewUser(c, false); var b = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var view = $"/api/v1/listings/{listing}/view";

        for (var i = 0; i < 3; i++) Assert.Equal(HttpStatusCode.NoContent, (await Call(c, a, HttpMethod.Post, view)).StatusCode);   // aynı kişi, aynı gün: tek sayılır
        await Call(c, b, HttpMethod.Post, view);                                                                                      // ikinci kişi
        await NewOffer(c, a, listing);
        var byShipperView = await Call(c, shipper, HttpMethod.Post, view);                                                            // rol: 403
        var unknownView = await Call(c, a, HttpMethod.Post, $"/api/v1/listings/{Guid.NewGuid()}/view");

        var stats = await Json(await Call(c, shipper, HttpMethod.Get, $"/api/v1/listings/{listing}/stats"));
        var byOther = await Call(c, other, HttpMethod.Get, $"/api/v1/listings/{listing}/stats");       // başkasının ilanı: 404
        var byCarrier = await Call(c, a, HttpMethod.Get, $"/api/v1/listings/{listing}/stats");         // rol: 403

        Assert.Equal(2, stats.GetProperty("viewCount").GetInt32());
        Assert.Equal(0, stats.GetProperty("favoriteCount").GetInt32());
        Assert.Equal(1, stats.GetProperty("offerCount").GetInt32());
        Assert.Equal(HttpStatusCode.Forbidden, byShipperView.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, unknownView.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, byOther.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, byCarrier.StatusCode);
    }

    [Fact]
    public async Task A_withdrawn_offer_is_not_counted_in_the_listing_stats()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper);
        var offer = await NewOffer(c, carrier, listing);
        await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/withdraw");

        var stats = await Json(await Call(c, shipper, HttpMethod.Get, $"/api/v1/listings/{listing}/stats"));

        Assert.Equal(0, stats.GetProperty("offerCount").GetInt32());
    }

    // ---------- hesap silme ----------
    private sealed record Account(string Token, string Email, string RefreshToken, string DeviceId);

    // NewUser'ın ayrıntılı hâli: silme sonrası "eski bilgilerle giriş olmuyor mu" diye bakabilmek için e-posta/yenileme jetonu da döner.
    private static async Task<Account> NewAccount(HttpClient c, bool shipper)
    {
        var token = await NewUser(c, shipper);
        var email = $"u{_counter}@x.com";   // NewUser'ın az önce kullandığı sayaç
        var deviceId = "dx" + _counter;
        var login = await Json(await c.PostAsJsonAsync("/api/v1/auth/login", new { emailOrPhone = email, password = "Abcdefg1", deviceId, deviceName = "t" }));
        return new Account(login.GetProperty("accessToken").GetString()!, email, login.GetProperty("refreshToken").GetString()!, deviceId);
    }

    private static Task<HttpResponseMessage> DeleteAccount(HttpClient c, string token, string? password) =>
        Call(c, token, HttpMethod.Post, "/api/v1/account/delete", new { password });

    [Fact]
    public async Task Deleting_a_shipper_cancels_open_listings_anonymizes_the_account_and_frees_the_email()
    {
        var c = await StartAsync();
        var shipper = await NewAccount(c, true); var carrier = await NewUser(c, false);
        var listing = await NewListing(c, shipper.Token);
        var offer = await NewOffer(c, carrier, listing);

        var delete = await DeleteAccount(c, shipper.Token, "Abcdefg1");
        var oldLogin = await c.PostAsJsonAsync("/api/v1/auth/login", new { emailOrPhone = shipper.Email, password = "Abcdefg1", deviceId = shipper.DeviceId, deviceName = "t" });
        var refresh = await c.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = shipper.RefreshToken, deviceId = shipper.DeviceId });
        var openForCarrier = await Items(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings"));
        var carrierOffers = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/offers/mine"));
        var reRegister = await c.PostAsJsonAsync("/api/v1/auth/register/shipper",
            new { fullName = "Yeni Hesap", email = shipper.Email, phone = "05329998877", password = "Abcdefg1", kvkkAccepted = true, termsAccepted = true });

        Assert.Equal(HttpStatusCode.NoContent, delete.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, oldLogin.StatusCode);              // eski bilgilerle giriş yok
        Assert.Equal(HttpStatusCode.Unauthorized, refresh.StatusCode);               // oturumlar kapandı
        Assert.Equal(0, openForCarrier.GetArrayLength());                             // açık ilan kaldırıldı
        Assert.Equal("Cancelled", carrierOffers[0].GetProperty("status").GetString());   // bekleyen teklif iptal oldu
        Assert.Equal("Silinmiş Kullanıcı", carrierOffers[0].GetProperty("shipperName").GetString());   // ad anonimleşti
        Assert.Equal(HttpStatusCode.Created, reRegister.StatusCode);                  // aynı e-posta yeniden kullanılabilir
    }

    [Fact]
    public async Task Deleting_a_carrier_withdraws_pending_offers_and_removes_favorites_and_views()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewAccount(c, false);
        var listing = await NewListing(c, shipper);
        await NewOffer(c, carrier.Token, listing);
        await Call(c, carrier.Token, HttpMethod.Put, $"/api/v1/listings/{listing}/favorite");
        await Call(c, carrier.Token, HttpMethod.Post, $"/api/v1/listings/{listing}/view");

        var delete = await DeleteAccount(c, carrier.Token, "Abcdefg1");
        var stats = await Json(await Call(c, shipper, HttpMethod.Get, $"/api/v1/listings/{listing}/stats"));
        var offers = await Json(await Call(c, shipper, HttpMethod.Get, $"/api/v1/listings/{listing}/offers"));

        Assert.Equal(HttpStatusCode.NoContent, delete.StatusCode);
        Assert.Equal(0, stats.GetProperty("favoriteCount").GetInt32());
        Assert.Equal(0, stats.GetProperty("viewCount").GetInt32());
        Assert.Equal(0, stats.GetProperty("offerCount").GetInt32());      // geri çekilen teklif sayılmaz
        Assert.Equal(0, offers.GetArrayLength());                          // Yük Veren cevaplanamaz teklif görmez
    }

    [Fact]
    public async Task Deleting_needs_the_right_password_and_a_wrong_one_does_not_end_the_session()
    {
        var c = await StartAsync();
        var shipper = await NewAccount(c, true);

        var wrong = await DeleteAccount(c, shipper.Token, "Yanlis123");
        var empty = await DeleteAccount(c, shipper.Token, "");
        var anonymous = await Call(c, null, HttpMethod.Post, "/api/v1/account/delete", new { password = "Abcdefg1" });
        var stillWorks = await Call(c, shipper.Token, HttpMethod.Get, "/api/v1/listings/mine");
        var login = await c.PostAsJsonAsync("/api/v1/auth/login", new { emailOrPhone = shipper.Email, password = "Abcdefg1", deviceId = "dz", deviceName = "t" });

        Assert.Equal(HttpStatusCode.BadRequest, wrong.StatusCode);                    // 401 değil: iOS oturumu bitirmesin
        Assert.Contains("Şifre hatalı", await wrong.Content.ReadAsStringAsync());
        Assert.Equal(HttpStatusCode.BadRequest, empty.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);
        Assert.Equal(HttpStatusCode.OK, stillWorks.StatusCode);                       // hesap ve oturum sağlam
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
    }

    [Fact]
    public async Task A_user_with_an_active_job_cannot_delete_until_it_is_completed()
    {
        var c = await StartAsync();
        var shipper = await NewAccount(c, true); var carrier = await NewAccount(c, false);
        var listing = await NewListing(c, shipper.Token);
        var offer = await NewOffer(c, carrier.Token, listing);
        await Call(c, shipper.Token, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");   // aktif iş

        var shipperBlocked = await DeleteAccount(c, shipper.Token, "Abcdefg1");
        var carrierBlocked = await DeleteAccount(c, carrier.Token, "Abcdefg1");

        await Deliver(c, carrier.Token, offer);
        await Call(c, carrier.Token, HttpMethod.Post, $"/api/v1/offers/{offer}/complete");
        var carrierOk = await DeleteAccount(c, carrier.Token, "Abcdefg1");
        var shipperOk = await DeleteAccount(c, shipper.Token, "Abcdefg1");

        Assert.Equal(HttpStatusCode.Conflict, shipperBlocked.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, carrierBlocked.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, carrierOk.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, shipperOk.StatusCode);
    }

    // K-021: hesap silinince puan ve yorum KALIR (karşı tarafın itibarı bozulmasın); yalnız yazarın adı anonimleşir.
    [Fact]
    public async Task A_deleted_shipper_keeps_the_rating_and_comment_on_the_carrier_profile_under_an_anonymous_name()
    {
        var c = await StartAsync();
        var shipper = await NewAccount(c, true); var carrier = await NewUser(c, false);
        var (offer, carrierId) = await CompletedJob(c, shipper.Token, carrier);
        await Call(c, shipper.Token, HttpMethod.Post, $"/api/v1/offers/{offer}/review", new { rating = 4, comment = "Zamanında teslim etti" });

        var deleted = await DeleteAccount(c, shipper.Token, "Abcdefg1");
        var profile = await Json(await Call(c, carrier, HttpMethod.Get, $"/api/v1/carriers/{carrierId}"));

        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);
        Assert.Equal(4m, profile.GetProperty("averageRating").GetDecimal());
        Assert.Equal(1, profile.GetProperty("ratingCount").GetInt32());
        var review = profile.GetProperty("reviews")[0];
        Assert.Equal("Zamanında teslim etti", review.GetProperty("comment").GetString());   // yorum metni durur
        Assert.DoesNotContain("Yuk Veren", review.GetProperty("shipperName").GetString()!);  // gerçek ad gitti
    }

    // İki yön: silinen Yük Veren'in işleri Taşımacı'nın geçmişinde, silinen Taşımacı'nın işleri/puanı Yük Veren'in geçmişinde ve profilinde KALIR.
    [Fact]
    public async Task Completed_jobs_stay_in_the_history_of_the_other_side_after_either_account_is_deleted()
    {
        var c = await StartAsync();
        var shipper = await NewAccount(c, true); var carrier = await NewAccount(c, false);
        var listing = await NewListing(c, shipper.Token);
        var offer = await NewOffer(c, carrier.Token, listing);
        await Call(c, shipper.Token, HttpMethod.Post, $"/api/v1/offers/{offer}/accept");
        await Deliver(c, carrier.Token, offer);
        await Call(c, shipper.Token, HttpMethod.Post, $"/api/v1/offers/{offer}/complete");   // işi Yük Veren bitirir → Taşımacı listesinde kalır
        await Call(c, shipper.Token, HttpMethod.Post, $"/api/v1/offers/{offer}/review", new { rating = 5, comment = "Çok iyi" });

        // 1) Yük Veren silinir → Taşımacı geçmişinde iş durur
        Assert.Equal(HttpStatusCode.NoContent, (await DeleteAccount(c, shipper.Token, "Abcdefg1")).StatusCode);
        var carrierHistory = await Json(await Call(c, carrier.Token, HttpMethod.Get, "/api/v1/offers/mine"));
        var mine = carrierHistory.EnumerateArray().Single(x => x.GetProperty("id").GetString() == offer);
        Assert.Equal("Completed", mine.GetProperty("status").GetString());
        Assert.False(string.IsNullOrEmpty(mine.GetProperty("shipperName").GetString()));

        // 2) Aynı iş için yeni bir Yük Veren + Taşımacı işi: Taşımacı silinir → Yük Veren geçmişinde iş ve profil durur
        var shipper2 = await NewAccount(c, true); var carrier2 = await NewAccount(c, false);
        var (offer2, carrier2Id) = await CompletedJob(c, shipper2.Token, carrier2.Token);
        await Call(c, shipper2.Token, HttpMethod.Post, $"/api/v1/offers/{offer2}/review", new { rating = 3, comment = "Orta" });
        Assert.Equal(HttpStatusCode.NoContent, (await DeleteAccount(c, carrier2.Token, "Abcdefg1")).StatusCode);

        var shipperHistory = await Json(await Call(c, shipper2.Token, HttpMethod.Get, "/api/v1/offers/history"));
        var row = shipperHistory.EnumerateArray().Single(x => x.GetProperty("id").GetString() == offer2);
        var profile = await Call(c, shipper2.Token, HttpMethod.Get, $"/api/v1/carriers/{carrier2Id}");

        Assert.False(string.IsNullOrEmpty(row.GetProperty("carrierName").GetString()));
        Assert.Equal(HttpStatusCode.OK, profile.StatusCode);
        var body = await Json(profile);
        Assert.Equal(3m, body.GetProperty("averageRating").GetDecimal());
        Assert.Equal("Orta", body.GetProperty("reviews")[0].GetProperty("comment").GetString());
    }


    // ---------- engelle + şikâyet et (15 Kasım, Apple 1.2) ----------
    private static async Task<string> MyId(HttpClient c, string token) =>
        (await Json(await Call(c, token, HttpMethod.Get, "/api/v1/account/me"))).GetProperty("id").GetString()!;

    private static async Task<bool> ListContains(HttpClient c, string carrier, string listingId)
    {
        var items = await Items(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings"));
        return items.EnumerateArray().Any(i => i.GetProperty("id").GetString() == listingId);
    }

    [Fact]
    public async Task Blocking_works_both_ways_hides_listings_stops_offers_and_messages_and_unblocking_restores_them()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var carrierId = await MyId(c, carrier);
        var first = await NewListing(c, shipper);
        var offer = await NewOffer(c, carrier, first);   // sohbet açık bir teklif
        var second = await NewListing(c, shipper);
        Assert.True(await ListContains(c, carrier, second));

        // Yük Veren engeller → Taşımacı tarafında da her şey kapanır (iki yönlü)
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, shipper, HttpMethod.Put, $"/api/v1/users/{carrierId}/block")).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, shipper, HttpMethod.Put, $"/api/v1/users/{carrierId}/block")).StatusCode); // idempotent
        var offerOnSecond = await Call(c, carrier, HttpMethod.Post, $"/api/v1/listings/{second}/offers",
            new { estimatedDeliveryDate = DateTime.UtcNow.AddDays(45).ToString("yyyy-MM-dd"), amount = 900, note = "x" });
        var carrierWrites = await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/messages", new { text = "merhaba" });
        var shipperWrites = await Call(c, shipper, HttpMethod.Post, $"/api/v1/offers/{offer}/messages", new { text = "merhaba" });
        var oldMessages = await Call(c, carrier, HttpMethod.Get, $"/api/v1/offers/{offer}/messages");
        var blocks = await Json(await Call(c, shipper, HttpMethod.Get, "/api/v1/account/blocks"));
        var carrierBlocks = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/account/blocks"));

        Assert.False(await ListContains(c, carrier, second));                        // ilan listeden düştü
        Assert.Equal(HttpStatusCode.Conflict, offerOnSecond.StatusCode);              // doğrudan istekle de teklif yok
        Assert.Equal(HttpStatusCode.Conflict, carrierWrites.StatusCode);             // engellenen yazamaz
        Assert.Equal(HttpStatusCode.Conflict, shipperWrites.StatusCode);             // engelleyen de yazamaz
        Assert.Equal(HttpStatusCode.OK, oldMessages.StatusCode);                      // eski mesajlar okunur (kanıt)
        Assert.Equal(1, blocks.GetArrayLength());
        Assert.Equal(carrierId, blocks[0].GetProperty("userId").GetString());
        Assert.StartsWith("Tasimaci", blocks[0].GetProperty("fullName").GetString());
        Assert.Equal(0, carrierBlocks.GetArrayLength());                             // engellenen, kimin engellediğini görmez

        // Engel kalkınca her şey geri gelir; yeniden engellenebilir (kalıcı silme benzersiz indeksi tıkamaz)
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, shipper, HttpMethod.Delete, $"/api/v1/users/{carrierId}/block")).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, shipper, HttpMethod.Delete, $"/api/v1/users/{carrierId}/block")).StatusCode); // idempotent
        Assert.True(await ListContains(c, carrier, second));
        Assert.Equal(HttpStatusCode.Created, (await Call(c, carrier, HttpMethod.Post, $"/api/v1/offers/{offer}/messages", new { text = "tekrar" })).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, shipper, HttpMethod.Put, $"/api/v1/users/{carrierId}/block")).StatusCode);
    }

    [Fact]
    public async Task A_carrier_blocking_a_shipper_also_hides_that_shippers_listings()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var shipperId = await MyId(c, shipper);
        var listing = await NewListing(c, shipper);
        await Call(c, carrier, HttpMethod.Put, $"/api/v1/listings/{listing}/favorite");

        await Call(c, carrier, HttpMethod.Put, $"/api/v1/users/{shipperId}/block");
        var favorites = await Json(await Call(c, carrier, HttpMethod.Get, "/api/v1/listings/favorites"));

        Assert.False(await ListContains(c, carrier, listing));
        Assert.Equal(0, favorites.GetArrayLength());   // favorilerden de düşer
    }

    [Fact]
    public async Task Block_and_report_reject_self_and_unknown_users_and_a_report_needs_a_valid_reason()
    {
        var c = await StartAsync();
        var shipper = await NewUser(c, true); var carrier = await NewUser(c, false);
        var shipperId = await MyId(c, shipper); var carrierId = await MyId(c, carrier);
        var unknown = Guid.NewGuid();

        Assert.Equal(HttpStatusCode.BadRequest, (await Call(c, shipper, HttpMethod.Put, $"/api/v1/users/{shipperId}/block")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await Call(c, shipper, HttpMethod.Put, $"/api/v1/users/{unknown}/block")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await Call(c, null, HttpMethod.Put, $"/api/v1/users/{carrierId}/block")).StatusCode);

        Assert.Equal(HttpStatusCode.BadRequest, (await Call(c, shipper, HttpMethod.Post, $"/api/v1/users/{carrierId}/report", new { note = "nedensiz" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Call(c, shipper, HttpMethod.Post, $"/api/v1/users/{carrierId}/report", new { reason = "Spam", note = new string('a', 501) })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Call(c, shipper, HttpMethod.Post, $"/api/v1/users/{shipperId}/report", new { reason = "Spam" })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await Call(c, shipper, HttpMethod.Post, $"/api/v1/users/{unknown}/report", new { reason = "Spam" })).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, shipper, HttpMethod.Post, $"/api/v1/users/{carrierId}/report", new { reason = "Fraud", note = "ön ödeme istedi" })).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, carrier, HttpMethod.Post, $"/api/v1/users/{shipperId}/report", new { reason = "Harassment" })).StatusCode); // iki rol de şikâyet eder
        Assert.Equal(HttpStatusCode.NoContent, (await Call(c, shipper, HttpMethod.Post, $"/api/v1/users/{carrierId}/report", new { reason = "Spam" })).StatusCode); // 24 saat içinde tekrar: sessizce başarılı
    }
}
