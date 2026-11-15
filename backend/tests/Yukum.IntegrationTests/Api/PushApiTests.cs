using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Time.Testing;
using Yukum.Application.Abstractions.Notifications;
using Yukum.Application.Notifications;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Api;

// Push (telefon bildirimi): cihaz jetonu uçları + bekleyen bildirimleri gönderen dağıtıcı (PushDispatcher).
// Apple'a gerçek istek atılmaz: IPushSender yerine sahte gönderici konur, "ne gönderilecekti" ona bakılarak doğrulanır.
[Collection("SqlServer")]
public class PushApiTests(SqlServerFixture sql)
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 25, 9, 0, 0, TimeSpan.Zero);
    private static int _counter;

    private sealed class FakePushSender : IPushSender
    {
        public List<PushMessage> Sent { get; } = [];
        public Func<PushMessage, PushResult> Result { get; set; } = _ => PushResult.Sent;

        public Task<PushResult> SendAsync(PushMessage message, CancellationToken cancellationToken = default)
        {
            Sent.Add(message);
            return Task.FromResult(Result(message));
        }
    }

    private sealed record App(WebApplicationFactory<Program> Factory, HttpClient C, FakePushSender Push, FakeTimeProvider Time)
    {
        // İşçinin bir turu: bekleyen bildirimleri gönderir (testte işçi kapalı, tur elle çalıştırılır)
        public async Task<int> Dispatch()
        {
            await using var scope = Factory.Services.CreateAsyncScope();
            return await scope.ServiceProvider.GetRequiredService<PushDispatcher>().DispatchPendingAsync();
        }
    }

    private async Task<App> StartAsync()
    {
        var database = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));
        var push = new FakePushSender();
        var time = new FakeTimeProvider(DateTimeOffset.UtcNow);   // gerçek "şimdi"den başlar (jetonlar geçerli kalsın), testte ileri sarılabilir
        var factory = new YukumApiFactory().WithWebHostBuilder(builder =>
        {
            builder.UseSetting("ConnectionStrings:DefaultConnection", database.ConnectionString);
            builder.ConfigureTestServices(services =>
            {
                services.RemoveAll<IPushSender>();
                services.AddSingleton<IPushSender>(push);
                services.RemoveAll<TimeProvider>();
                services.AddSingleton<TimeProvider>(time);
            });
        });
        return new App(factory, factory.CreateClient(), push, time);
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
        var email = $"p{n}@x.com";
        var phone = $"0534{3000000 + n}";
        object body = shipper
            ? new { fullName = $"Yuk Veren {n}", email, phone, password = "Abcdefg1", cityId = 33, kvkkAccepted = true, termsAccepted = true }
            : new
            {
                fullName = $"Tasimaci {n}", email, phone, password = "Abcdefg1", homeCityId = 33, serviceCityIds = new[] { 33 },
                vehicles = new object[] { new { type = "Truck", capacityKg = 24000, brand = "Volvo", model = "FH", year = 2020 } }, kvkkAccepted = true, termsAccepted = true
            };
        Assert.Equal(HttpStatusCode.Created, (await c.PostAsJsonAsync(shipper ? "/api/v1/auth/register/shipper" : "/api/v1/auth/register/carrier", body)).StatusCode);
        var login = await c.PostAsJsonAsync("/api/v1/auth/login", new { emailOrPhone = email, password = "Abcdefg1", deviceId = "pd" + n, deviceName = "test" });
        return (await Json(login)).GetProperty("accessToken").GetString()!;
    }

    private static async Task<string> NewListing(HttpClient c, string shipperToken)
    {
        var from = (await Json(await c.GetAsync("/api/v1/cities/33/districts")))[0].GetProperty("id").GetInt32();
        var to = (await Json(await c.GetAsync("/api/v1/cities/34/districts")))[0].GetProperty("id").GetInt32();
        var r = await Call(c, shipperToken, HttpMethod.Post, "/api/v1/listings", new
        {
            title = "Push ilanı", weightKg = 1000, vehicleType = "Truck", fromCityId = 33, fromDistrictId = from, toCityId = 34, toDistrictId = to,
            pickupDate = DateTime.UtcNow.AddDays(30).ToString("yyyy-MM-dd"), budget = 5000
        });
        Assert.Equal(HttpStatusCode.Created, r.StatusCode);
        return (await Json(r)).GetProperty("id").GetString()!;
    }

    // Teklif verir: Yük Veren'e "Yeni teklif" bildirimi yazılır
    private static async Task Offer(HttpClient c, string carrierToken, string listingId, decimal amount = 1000) =>
        Assert.Equal(HttpStatusCode.OK, (await Call(c, carrierToken, HttpMethod.Post, $"/api/v1/listings/{listingId}/offers", new { estimatedDeliveryDate = DateTime.UtcNow.AddDays(45).ToString("yyyy-MM-dd"), amount, note = "not" })).StatusCode);

    private static string DeviceToken(char fill) => new(fill, 64);   // 64 onaltılık karakter

    private static Task<HttpResponseMessage> Register(HttpClient c, string? token, string deviceToken, string deviceId = "telefon-1", bool sandbox = true) =>
        Call(c, token, HttpMethod.Put, "/api/v1/notifications/device-token", new { token = deviceToken, deviceId, sandbox });

    [Fact]
    public async Task A_notification_is_pushed_once_to_the_owners_phone_with_text_badge_and_target()
    {
        var app = await StartAsync();
        var shipper = await NewUser(app.C, true); var carrier = await NewUser(app.C, false);
        var listing = await NewListing(app.C, shipper);
        Assert.Equal(HttpStatusCode.NoContent, (await Register(app.C, shipper, DeviceToken('a'))).StatusCode);
        await Offer(app.C, carrier, listing);

        var sent = await app.Dispatch();
        var again = await app.Dispatch();

        Assert.Equal(1, sent);
        Assert.Equal(0, again);                                   // PushedAt işaretlendi: ikinci turda tekrar gönderilmez
        var message = Assert.Single(app.Push.Sent);
        Assert.Equal(DeviceToken('a'), message.Token);
        Assert.True(message.Sandbox);
        Assert.Equal("Yeni teklif", message.Title);
        Assert.Contains("Push ilanı", message.Body);
        Assert.Equal(1, message.Badge);                           // okunmamış sayısı = uygulama simgesindeki sayı
        Assert.Equal("OfferReceived", message.Type);
        Assert.Equal(listing, message.ListingId.ToString());
    }

    [Fact]
    public async Task Without_a_registered_phone_nothing_is_sent_and_old_notifications_are_not_replayed_later()
    {
        var app = await StartAsync();
        var shipper = await NewUser(app.C, true); var carrier = await NewUser(app.C, false);
        var listing = await NewListing(app.C, shipper);
        await Offer(app.C, carrier, listing);

        var beforeRegister = await app.Dispatch();
        await Register(app.C, shipper, DeviceToken('a'));
        var afterRegister = await app.Dispatch();

        Assert.Equal(0, beforeRegister);
        Assert.Equal(0, afterRegister);      // telefon sonradan kaydolunca eski bildirimler yağmaz
        Assert.Empty(app.Push.Sent);
    }

    [Fact]
    public async Task An_invalid_token_is_removed_and_a_temporary_failure_is_retried()
    {
        var app = await StartAsync();
        var shipper = await NewUser(app.C, true); var carrier = await NewUser(app.C, false);
        var listing = await NewListing(app.C, shipper);
        await Register(app.C, shipper, DeviceToken('a'), "telefon-1");
        await Register(app.C, shipper, DeviceToken('b'), "telefon-2");
        await Offer(app.C, carrier, listing);

        // 'a' geçersiz (uygulama silinmiş), 'b' geçici hata veriyor
        app.Push.Result = m => m.Token == DeviceToken('a') ? PushResult.InvalidToken : PushResult.Failed;
        var first = await app.Dispatch();
        app.Push.Result = _ => PushResult.Sent;
        var second = await app.Dispatch();
        var third = await app.Dispatch();

        Assert.Equal(0, first);
        Assert.Equal(1, second);                                              // yalnız 'b' yeniden denendi
        Assert.Equal(0, third);
        Assert.Equal(1, app.Push.Sent.Count(m => m.Token == DeviceToken('a'))); // geçersiz jeton silindi, bir daha denenmedi
        Assert.Equal(2, app.Push.Sent.Count(m => m.Token == DeviceToken('b')));
    }

    [Fact]
    public async Task A_stale_notification_is_not_pushed()
    {
        var app = await StartAsync();
        var shipper = await NewUser(app.C, true); var carrier = await NewUser(app.C, false);
        var listing = await NewListing(app.C, shipper);
        await Register(app.C, shipper, DeviceToken('a'));
        await Offer(app.C, carrier, listing);

        app.Time.Advance(TimeSpan.FromHours(2));   // işçi 2 saat çalışmamış gibi
        var sent = await app.Dispatch();

        Assert.Equal(0, sent);
        Assert.Empty(app.Push.Sent);               // bayat haber telefona gitmez (uygulama içi listede durur)
    }

    [Fact]
    public async Task A_phone_belongs_to_the_last_user_who_registered_it_and_logout_stops_pushes()
    {
        var app = await StartAsync();
        var shipperA = await NewUser(app.C, true); var shipperB = await NewUser(app.C, true); var carrier = await NewUser(app.C, false);
        var listingA = await NewListing(app.C, shipperA); var listingB = await NewListing(app.C, shipperB);

        // Aynı telefon: önce A, sonra B giriş yapıyor → adres B'ye geçer
        await Register(app.C, shipperA, DeviceToken('a'));
        await Register(app.C, shipperB, DeviceToken('a'));
        await Offer(app.C, carrier, listingA);
        await Offer(app.C, carrier, listingB);
        await app.Dispatch();
        Assert.Contains(listingB, Assert.Single(app.Push.Sent).ListingId.ToString());   // yalnız B'nin bildirimi gitti

        // B çıkış yapıyor → adres silinir, yeni bildirim gitmez
        var removed = await Call(app.C, shipperB, HttpMethod.Delete, "/api/v1/notifications/device-token?deviceId=telefon-1");
        var removedAgain = await Call(app.C, shipperB, HttpMethod.Delete, "/api/v1/notifications/device-token?deviceId=telefon-1");
        await Offer(app.C, carrier, listingB, 900);
        await app.Dispatch();

        Assert.Equal(HttpStatusCode.NoContent, removed.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, removedAgain.StatusCode);   // idempotent
        Assert.Single(app.Push.Sent);
    }

    [Fact]
    public async Task Device_token_endpoint_validates_input_is_idempotent_and_refuses_anonymous()
    {
        var app = await StartAsync();
        var shipper = await NewUser(app.C, true);

        var ok = await Register(app.C, shipper, DeviceToken('a'));
        var same = await Register(app.C, shipper, DeviceToken('a'));
        var notHex = await Register(app.C, shipper, new string('z', 64));
        var tooShort = await Register(app.C, shipper, "abc123");
        var noDevice = await Register(app.C, shipper, DeviceToken('b'), deviceId: "");
        var anonymous = await Register(app.C, null, DeviceToken('a'));

        Assert.Equal(HttpStatusCode.NoContent, ok.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, same.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, notHex.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, tooShort.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, noDevice.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);
    }

    [Fact]
    public async Task Deleting_the_account_removes_its_phones()
    {
        var app = await StartAsync();
        var shipper = await NewUser(app.C, true); var carrier = await NewUser(app.C, false);
        var listing = await NewListing(app.C, shipper);
        await Register(app.C, carrier, DeviceToken('c'));
        await Offer(app.C, carrier, listing);
        await app.Dispatch();   // Yük Veren'in telefonu yok: bir şey gitmez
        Assert.Equal(HttpStatusCode.NoContent, (await Call(app.C, carrier, HttpMethod.Post, "/api/v1/account/delete", new { password = "Abcdefg1" })).StatusCode);

        // İlan kaldırılsa bile silinen Taşımacı'nın telefonuna bildirim gitmez (teklifi zaten geri çekildi, adresi silindi)
        await Call(app.C, shipper, HttpMethod.Post, $"/api/v1/listings/{listing}/cancel");
        await app.Dispatch();

        Assert.Empty(app.Push.Sent);
    }
}
