using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Yukum.Application.Abstractions.Notifications;

namespace Yukum.Infrastructure.Push;

/// <summary>
/// <see cref="IPushSender"/>'ın Apple (APNs) uygulaması. HTTP/2 ile POST /3/device/{jeton}; kimlik .p8 anahtarıyla imzalı JWT.
/// Geliştirme sürümünün jetonu "sandbox", yayın sürümününki "production" sunucusuna gider; karıştırılırsa Apple BadDeviceToken döner.
/// </summary>
public sealed class ApnsPushSender(HttpClient http, ApnsJwtFactory jwt, IOptions<ApnsOptions> options, ILogger<ApnsPushSender> logger) : IPushSender
{
    private const string SandboxHost = "https://api.sandbox.push.apple.com";
    private const string ProductionHost = "https://api.push.apple.com";

    /// <inheritdoc />
    public async Task<PushResult> SendAsync(PushMessage message, CancellationToken cancellationToken = default)
    {
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, $"{(message.Sandbox ? SandboxHost : ProductionHost)}/3/device/{message.Token}")
            {
                Version = HttpVersion.Version20,                        // APNs yalnız HTTP/2 kabul eder
                VersionPolicy = HttpVersionPolicy.RequestVersionExact,
                Content = JsonContent.Create(new Dictionary<string, object?>
                {
                    // aps: Apple'ın okuduğu kısım (ekranda görünen yazı, ses, simge sayısı). Diğer alanlar uygulamaya gelir (dokununca nereye gidilecek).
                    ["aps"] = new { alert = new { title = message.Title, body = message.Body }, sound = "default", badge = message.Badge },
                    ["notificationId"] = message.NotificationId,
                    ["type"] = message.Type,
                    ["listingId"] = message.ListingId,
                    ["offerId"] = message.OfferId
                })
            };
            request.Headers.Authorization = new AuthenticationHeaderValue("bearer", jwt.GetToken());
            request.Headers.TryAddWithoutValidation("apns-topic", options.Value.BundleId);
            request.Headers.TryAddWithoutValidation("apns-push-type", "alert");
            request.Headers.TryAddWithoutValidation("apns-priority", "10");

            using var response = await http.SendAsync(request, cancellationToken);
            if (response.IsSuccessStatusCode) return PushResult.Sent;

            var reason = await ReadReasonAsync(response, cancellationToken);
            // 410 = jeton artık geçerli değil; 400 + bu nedenler = jeton hatalı ya da bu uygulamaya/ortama ait değil
            if (response.StatusCode == HttpStatusCode.Gone || reason is "BadDeviceToken" or "Unregistered" or "DeviceTokenNotForTopic")
                return PushResult.InvalidToken;

            logger.LogWarning("APNs push reddedildi: {Status} {Reason}", (int)response.StatusCode, reason);
            return PushResult.Failed;
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogWarning(exception, "APNs push gönderilemedi");
            return PushResult.Failed;
        }
    }

    private static async Task<string?> ReadReasonAsync(HttpResponseMessage response, CancellationToken cancellationToken)
    {
        try
        {
            var body = await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken);
            return body.TryGetProperty("reason", out var reason) ? reason.GetString() : null;
        }
        catch (JsonException) { return null; }
    }
}
