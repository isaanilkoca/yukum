using Yukum.Domain.Common;

namespace Yukum.Domain.Accounts;

/// <summary>
/// Bir kullanıcının başka bir kullanıcıyı şikâyet etmesi (15 Kasım, Apple 1.2: "şikâyet et" şart).
/// İnceleme ekranı yönetici panelinde gelecek; o zamana kadar SQL'den okunur (docs/sql).
/// Hangi ilan / sohbet üzerinden şikâyet edildiği isteğe bağlı bağlamdır (incelemeyi kolaylaştırır).
/// </summary>
// BAĞLANTI HARİTASI: SafetyController (POST /reports) → ReportUserHandler → IRepository&lt;UserReport&gt; → "UserReports" tablosu
public class UserReport : BaseEntity
{
    /// <summary>Şikâyet eden.</summary>
    public Guid ReporterId { get; set; }

    /// <summary>Şikâyet edilen.</summary>
    public Guid ReportedUserId { get; set; }

    /// <summary>Neden.</summary>
    public ReportReason Reason { get; set; }

    /// <summary>Kullanıcının notu (en çok 500 karakter, boş olabilir).</summary>
    public string? Note { get; set; }

    /// <summary>Şikâyet bir ilan ekranından geldiyse o ilan.</summary>
    public Guid? ListingId { get; set; }

    /// <summary>Şikâyet bir sohbetten geldiyse o teklif (sohbet teklife bağlıdır).</summary>
    public Guid? OfferId { get; set; }
}
