namespace Yukum.Domain.Accounts;

/// <summary>Şikâyet nedeni. Veritabanında sayı olarak saklanır; yeni neden eklenebilir, mevcut sayılar değişmez.</summary>
public enum ReportReason
{
    /// <summary>Dolandırıcılık (ön ödeme isteme, sahte firma).</summary>
    Fraud = 1,

    /// <summary>Hakaret, taciz, tehdit.</summary>
    Harassment = 2,

    /// <summary>Sahte ya da yanıltıcı ilan.</summary>
    FakeListing = 3,

    /// <summary>Spam, reklam, alakasız içerik.</summary>
    Spam = 4,

    /// <summary>Listede olmayan neden (not yazılması beklenir ama zorunlu değil).</summary>
    Other = 99
}
