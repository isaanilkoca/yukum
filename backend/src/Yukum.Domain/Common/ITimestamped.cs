namespace Yukum.Domain.Common;

/// <summary>
/// "Ne zaman oluşturuldu / son ne zaman değişti" bilgisini taşıyan kayıtların ortak sözleşmesi.
/// <c>AppDbContext</c> bu alanları kaydederken otomatik doldurur. <see cref="BaseEntity"/> bunu uygular;
/// kendi taban sınıfı olan kullanıcı kaydı (Identity) da aynı kuralı alabilsin diye ayrı bir arayüz olarak tutulur.
/// </summary>
public interface ITimestamped
{
    /// <summary>Oluşturulma zamanı (UTC). Elle yazılmaz, sonradan değiştirilemez.</summary>
    DateTime CreatedAt { get; set; }

    /// <summary>Son değiştirilme zamanı (UTC). Hiç değişmediyse boştur.</summary>
    DateTime? UpdatedAt { get; set; }
}
