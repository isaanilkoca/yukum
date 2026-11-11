namespace Yukum.Application.Abstractions.Notifications;

/// <summary>Telefona gidecek tek bir push. Sandbox: jetonun ait olduğu APNs ortamı.</summary>
public sealed record PushMessage(string Token, bool Sandbox, string Title, string Body, int Badge,
    Guid NotificationId, string Type, Guid? ListingId, Guid? OfferId);

/// <summary>Gönderim sonucu.</summary>
public enum PushResult
{
    /// <summary>Apple kabul etti.</summary>
    Sent,

    /// <summary>Jeton geçersiz (uygulama silinmiş, jeton değişmiş): jeton silinmeli, tekrar denenmez.</summary>
    InvalidToken,

    /// <summary>Geçici hata (ağ, Apple tarafı, yapılandırma): sonra tekrar denenir.</summary>
    Failed
}

/// <summary>Push gönderen servis. İş kuralı Apple'ı bilmez; gerçek uygulama Infrastructure'da (ApnsPushSender), testte sahtesi verilir.</summary>
public interface IPushSender
{
    /// <summary>Tek bir push gönderir. Hata fırlatmaz, sonucu döner.</summary>
    Task<PushResult> SendAsync(PushMessage message, CancellationToken cancellationToken = default);
}
