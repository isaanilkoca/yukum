using System.Net;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Time.Testing;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Notifications;
using Yukum.Infrastructure.Identity;
using Yukum.Infrastructure.Push;

namespace Yukum.IntegrationTests.Data;

// DIŞARIYA İSTEK ATAN GÖNDERİCİLER (15 Kasım): ApnsPushSender (Apple) ve ResendEmailSender (Resend).
// Gerçek ağ YOK: sahte HttpMessageHandler isteği yakalar, istenen cevabı döner. Sınanan: doğru adres/başlık/gövde + her cevap türüne doğru tepki.
// Kapsam ölçümünde bu iki dosya %3 ve %14'te kalmıştı (yalnız gerçek cihaz/hesapla elle denenmişti).
public class OutboundSendersTests
{
    // İsteği kaydeden, cevabı testin belirlediği sahte HTTP katmanı (istisna da fırlatabilir: ağ kopması)
    private sealed class FakeHandler(Func<HttpRequestMessage, HttpResponseMessage> respond) : HttpMessageHandler
    {
        public List<(HttpRequestMessage Request, string Body)> Calls { get; } = [];
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var body = request.Content is null ? "" : await request.Content.ReadAsStringAsync(cancellationToken);
            Calls.Add((request, body));
            return respond(request);
        }
    }

    private sealed class CapturingSender : IEmailSender
    {
        public List<(string To, string Subject, string Body)> Sent { get; } = [];
        public Task SendAsync(string to, string subject, string body, CancellationToken cancellationToken = default)
        { Sent.Add((to, subject, body)); return Task.CompletedTask; }
    }

    private static HttpResponseMessage Status(HttpStatusCode code, string json = "{}") =>
        new(code) { Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json") };

    // ─────────────── Resend ───────────────

    private static ResendEmailSender Resend(FakeHandler handler, IEmailSender? fallback = null) =>
        new(new HttpClient(handler), Options.Create(new EmailOptions { ResendApiKey = "re_test", From = "Yüküm <onboarding@resend.dev>" }),
            NullLogger<ResendEmailSender>.Instance, fallback);

    [Fact]
    public async Task Resend_posts_the_email_with_the_key_and_does_not_use_the_fallback_on_success()
    {
        var handler = new FakeHandler(_ => Status(HttpStatusCode.OK, """{"id":"1"}"""));
        var fallback = new CapturingSender();

        await Resend(handler, fallback).SendAsync("ayse@x.com", "Kodun", "123456");

        var (request, body) = Assert.Single(handler.Calls);
        Assert.Equal(HttpMethod.Post, request.Method);
        Assert.Equal("https://api.resend.com/emails", request.RequestUri!.ToString());
        Assert.Equal("Bearer re_test", request.Headers.Authorization!.ToString());
        var json = JsonDocument.Parse(body).RootElement;
        Assert.Equal("Yüküm <onboarding@resend.dev>", json.GetProperty("from").GetString());
        Assert.Equal("ayse@x.com", json.GetProperty("to")[0].GetString());   // Resend "to" alanını dizi ister
        Assert.Equal("Kodun", json.GetProperty("subject").GetString());
        Assert.Equal("123456", json.GetProperty("text").GetString());
        Assert.Empty(fallback.Sent);
    }

    [Theory]
    [InlineData(HttpStatusCode.Forbidden)]            // alan adı yokken başka adres (Resend 403)
    [InlineData(HttpStatusCode.UnprocessableEntity)] // geçersiz alıcı (422)
    [InlineData(HttpStatusCode.TooManyRequests)]     // kota
    public async Task A_rejected_email_goes_to_the_fallback_and_never_throws(HttpStatusCode status)
    {
        var fallback = new CapturingSender();

        await Resend(new FakeHandler(_ => Status(status, """{"message":"hayır"}""")), fallback).SendAsync("baska@x.com", "Kodun", "654321");

        var copy = Assert.Single(fallback.Sent);   // geliştirmede kod günlüğe düşer
        Assert.Equal("baska@x.com", copy.To);
        Assert.Equal("654321", copy.Body);
    }

    [Fact]
    public async Task A_network_failure_is_swallowed_and_falls_back()
    {
        var fallback = new CapturingSender();
        var sender = Resend(new FakeHandler(_ => throw new HttpRequestException("bağlantı yok")), fallback);

        await sender.SendAsync("a@x.com", "Kodun", "111111");   // istisna dışarı sızmaz: kayıt isteği 500'e düşmez

        Assert.Single(fallback.Sent);
    }

    [Fact]
    public async Task Without_a_fallback_a_failure_is_only_logged()
    {
        var sender = Resend(new FakeHandler(_ => Status(HttpStatusCode.Forbidden)), fallback: null); // canlı ortam ayarı

        var error = await Record.ExceptionAsync(() => sender.SendAsync("a@x.com", "Kodun", "222222"));

        Assert.Null(error);
    }

    // ─────────────── APNs ───────────────

    // Test için üretilmiş P-256 anahtarı (.p8 biçiminde, geçici dosya) — gerçek Apple anahtarına dokunulmaz
    private static ApnsPushSender Apns(FakeHandler handler)
    {
        var path = Path.Combine(Path.GetTempPath(), $"yukum-test-{Guid.NewGuid():N}.p8");
        using (var key = ECDsa.Create(ECCurve.NamedCurves.nistP256)) File.WriteAllText(path, key.ExportPkcs8PrivateKeyPem());
        var options = Options.Create(new ApnsOptions { Enabled = true, KeyPath = path, KeyId = "KEY1234567", TeamId = "TEAM123456", BundleId = "com.isaanilkoca.Yukum" });
        return new ApnsPushSender(new HttpClient(handler), new ApnsJwtFactory(options, new FakeTimeProvider(DateTimeOffset.UtcNow)), options, NullLogger<ApnsPushSender>.Instance);
    }

    private static PushMessage Message(bool sandbox = true) =>
        new("abc123", sandbox, "Yeni teklif", "İlanına 4.500 ₺ teklif geldi", 3, Guid.NewGuid(), "OfferReceived", Guid.NewGuid(), Guid.NewGuid());

    [Fact]
    public async Task Apns_sends_an_http2_alert_with_a_signed_token_topic_and_deep_link_fields()
    {
        var handler = new FakeHandler(_ => Status(HttpStatusCode.OK));
        var message = Message(sandbox: true);

        var result = await Apns(handler).SendAsync(message);

        Assert.Equal(PushResult.Sent, result);
        var (request, body) = Assert.Single(handler.Calls);
        Assert.Equal("https://api.sandbox.push.apple.com/3/device/abc123", request.RequestUri!.ToString()); // geliştirme jetonu → sandbox
        Assert.Equal(HttpVersion.Version20, request.Version);
        Assert.Equal("com.isaanilkoca.Yukum", request.Headers.GetValues("apns-topic").Single());
        Assert.Equal("alert", request.Headers.GetValues("apns-push-type").Single());
        var jwt = request.Headers.Authorization!.Parameter!.Split('.');
        Assert.Equal(3, jwt.Length);                                                  // başlık.yük.imza
        var header = JsonDocument.Parse(Convert.FromBase64String(Pad(jwt[0]))).RootElement;
        Assert.Equal("ES256", header.GetProperty("alg").GetString());
        Assert.Equal("KEY1234567", header.GetProperty("kid").GetString());
        var json = JsonDocument.Parse(body).RootElement;
        Assert.Equal("Yeni teklif", json.GetProperty("aps").GetProperty("alert").GetProperty("title").GetString());
        Assert.Equal(3, json.GetProperty("aps").GetProperty("badge").GetInt32());
        Assert.Equal("OfferReceived", json.GetProperty("type").GetString());        // iOS bildirime dokununca doğru ekranı açar
        Assert.Equal(message.OfferId.ToString(), json.GetProperty("offerId").GetString());
    }

    [Fact]
    public async Task Apns_production_tokens_go_to_the_production_host()
    {
        var handler = new FakeHandler(_ => Status(HttpStatusCode.OK));
        await Apns(handler).SendAsync(Message(sandbox: false));
        Assert.StartsWith("https://api.push.apple.com/", handler.Calls.Single().Request.RequestUri!.ToString());
    }

    [Theory]
    [InlineData(HttpStatusCode.Gone, "{}")]                                      // uygulama silinmiş
    [InlineData(HttpStatusCode.BadRequest, """{"reason":"BadDeviceToken"}""")]
    [InlineData(HttpStatusCode.BadRequest, """{"reason":"DeviceTokenNotForTopic"}""")]
    [InlineData(HttpStatusCode.BadRequest, """{"reason":"Unregistered"}""")]
    public async Task Dead_device_tokens_are_reported_as_invalid_so_the_worker_deletes_them(HttpStatusCode status, string body)
    {
        Assert.Equal(PushResult.InvalidToken, await Apns(new FakeHandler(_ => Status(status, body))).SendAsync(Message()));
    }

    [Theory]
    [InlineData(HttpStatusCode.TooManyRequests, """{"reason":"TooManyRequests"}""")]
    [InlineData(HttpStatusCode.InternalServerError, "bozuk json")]                 // gövde okunamazsa da çökmez
    [InlineData(HttpStatusCode.Forbidden, """{"reason":"ExpiredProviderToken"}""")]
    public async Task Other_rejections_are_failures_and_the_token_is_kept(HttpStatusCode status, string body)
    {
        Assert.Equal(PushResult.Failed, await Apns(new FakeHandler(_ => Status(status, body))).SendAsync(Message()));
    }

    [Fact]
    public async Task A_network_failure_is_a_failure_not_an_exception()
    {
        var result = await Apns(new FakeHandler(_ => throw new HttpRequestException("ağ yok"))).SendAsync(Message());
        Assert.Equal(PushResult.Failed, result);
    }

    [Fact]
    public async Task The_signed_token_is_reused_instead_of_signing_every_push()
    {
        var handler = new FakeHandler(_ => Status(HttpStatusCode.OK));
        var sender = Apns(handler);

        await sender.SendAsync(Message()); await sender.SendAsync(Message());

        // Apple sık jeton üretimini kısıtlar (20 dk'dan sık yenileme reddedilir): iki push aynı jetonu taşır
        Assert.Equal(handler.Calls[0].Request.Headers.Authorization!.Parameter, handler.Calls[1].Request.Headers.Authorization!.Parameter);
    }

    private static string Pad(string base64Url)
    {
        var s = base64Url.Replace('-', '+').Replace('_', '/');
        return s + new string('=', (4 - s.Length % 4) % 4);
    }
}
