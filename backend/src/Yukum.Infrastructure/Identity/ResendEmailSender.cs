using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Yukum.Application.Abstractions.Identity;

namespace Yukum.Infrastructure.Identity;

/// <summary>"Email" ayar bölümü (15 Kasım). Anahtar YALNIZ user-secrets'ta (geliştirme) / ortam değişkeninde (canlı) durur, depoya girmez.</summary>
public sealed class EmailOptions
{
    /// <summary>Resend API anahtarı ("re_..."). Boşsa e-postalar günlüğe yazılır (LogEmailSender).</summary>
    public string ResendApiKey { get; set; } = "";

    /// <summary>
    /// Gönderen adres. Alan adı yokken Resend'in deneme adresi: yalnız Resend hesabının KENDİ e-postasına gönderebilir (başkasına 403).
    /// Alan adı doğrulanınca (resend.com/domains) "Yüküm &lt;noreply@alanadi&gt;" yapılır — başka kod değişmez.
    /// </summary>
    public string From { get; set; } = "Yüküm <onboarding@resend.dev>";

    /// <summary>
    /// YALNIZ GELİŞTİRME (appsettings.Development.json): Resend gönderemezse (ör. alan adı yokken başka adres → 403) e-posta günlüğe yazılır,
    /// böylece deneme hesaplarının kodu da okunabilir. Canlıda true ise Program.cs uygulamayı AÇMAZ (kod günlüğe düşmesin).
    /// </summary>
    public bool FallbackToLog { get; set; }
}

/// <summary>
/// Resend ile gerçek e-posta (15 Kasım). Paket yok: Resend'in REST ucuna tek POST (https://api.resend.com/emails).
/// HATA YUTULUR (günlüğe yazılır): e-posta gitmedi diye kayıt / şifre sıfırlama isteği 500'e düşmesin; kullanıcı "Kodu yeniden gönder"e basar.
/// </summary>
// BAĞLANTI HARİTASI: VerificationService.SendCodeAsync → IEmailSender → (anahtar varsa) ResendEmailSender → api.resend.com
//   seçim: Infrastructure/DependencyInjection (Email:ResendApiKey dolu mu) | anahtar: dotnet user-secrets (Yukum.Api)
public sealed class ResendEmailSender(HttpClient http, IOptions<EmailOptions> options, ILogger<ResendEmailSender> logger, IEmailSender? fallback = null) : IEmailSender
{
    /// <inheritdoc />
    public async Task SendAsync(string to, string subject, string body, CancellationToken cancellationToken = default)
    {
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, "https://api.resend.com/emails")
            {
                // Resend'in beklediği gövde: from, to (dizi), subject, text (düz metin)
                Content = JsonContent.Create(new { from = options.Value.From, to = new[] { to }, subject, text = body })
            };
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", options.Value.ResendApiKey);
            using var response = await http.SendAsync(request, cancellationToken);
            if (response.IsSuccessStatusCode) return;
            // Alıcı adresi ve gövde (kod!) bu satıra YAZILMAZ; yalnız durum ve Resend'in hata metni
            logger.LogError("Resend e-postası gönderilemedi: {Status} {Error}", (int)response.StatusCode, await response.Content.ReadAsStringAsync(cancellationToken));
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
        {
            logger.LogError(ex, "Resend'e ulaşılamadı.");
        }
        // Gönderilemedi: geliştirmede yedek (LogEmailSender) e-postayı günlük dosyasına yazar; canlıda fallback yok (null)
        if (fallback is not null) await fallback.SendAsync(to, subject, body, cancellationToken);
    }
}
