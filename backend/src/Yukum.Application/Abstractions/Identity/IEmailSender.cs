namespace Yukum.Application.Abstractions.Identity;

/// <summary>
/// E-posta gönderir. Uygulama hangi servisle gönderildiğini bilmez (15 Kasım):
/// geliştirmede Infrastructure/Identity/LogEmailSender (API günlüğüne yazar), canlıda Resend (alan adı alınınca eklenecek).
/// Servis değişince yalnız Infrastructure/DependencyInjection'daki kayıt değişir.
/// </summary>
public interface IEmailSender
{
    /// <summary>Düz metin e-posta gönderir.</summary>
    Task SendAsync(string to, string subject, string body, CancellationToken cancellationToken = default);
}
