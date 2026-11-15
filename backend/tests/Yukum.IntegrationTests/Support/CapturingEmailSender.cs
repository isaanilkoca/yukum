using System.Collections.Concurrent;
using System.Text.RegularExpressions;
using Yukum.Application.Abstractions.Identity;

namespace Yukum.IntegrationTests.Support;

// Testte "gönderilen" e-postaları bellekte tutar; kod gövdeden okunur (gerçek kullanıcının e-postadan okuması gibi).
public sealed partial class CapturingEmailSender : IEmailSender
{
    public ConcurrentQueue<(string To, string Subject, string Body)> Sent { get; } = new();

    public Task SendAsync(string to, string subject, string body, CancellationToken cancellationToken = default)
    {
        Sent.Enqueue((to, subject, body));
        return Task.CompletedTask;
    }

    // Belirtilen adrese giden son e-postadaki 6 haneli kod
    public string LastCode(string to) => SixDigits().Match(Sent.Last(m => m.To == to).Body).Value;

    [GeneratedRegex(@"\b\d{6}\b")]
    private static partial Regex SixDigits();
}
