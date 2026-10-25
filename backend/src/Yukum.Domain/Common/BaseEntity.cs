namespace Yukum.Domain.Common;

/// <summary>
/// Veritabanındaki tüm tabloların (ilan, teklif, kullanıcı...) ortak taban sınıfı.
/// Aynı alanları her tabloda tekrar yazmamak için bir kez burada tanımlanır.
/// Domain katmanı hiçbir pakete bağlı değildir; EF Core'u veya SQL Server'ı bilmez.
/// </summary>
public abstract class BaseEntity : ITimestamped
{
    /// <summary>
    /// Kayıt numarası (GUID): tahmin edilemez, başkasının kaydını numara deneyerek bulamazsın.
    /// Kayıt eklenene kadar boştur (<see cref="Guid.Empty"/>); EF Core, SQL Server için sıralı GUID'i üretir (karar K-012).
    /// </summary>
    public Guid Id { get; protected set; }

    /// <summary>Kaydın oluşturulma zamanı (UTC). Elle yazılmaz; <c>AppDbContext</c> kaydederken doldurur ve sonradan değiştirilemez.</summary>
    public DateTime CreatedAt { get; set; }
    /// <summary>Kaydın son değiştirilme zamanı (UTC). Hiç değişmediyse boştur (null). <c>AppDbContext</c> doldurur.</summary>
    public DateTime? UpdatedAt { get; set; }

    /// <summary>
    /// Yumuşak silme işareti: kayıt veritabanından gerçekten silinmez, yalnızca işaretlenir.
    /// İşaretli kayıtlar normal sorgularda görünmez (ilan/yorum gibi iz kalması gerekenler için).
    /// </summary>
    public bool IsDeleted { get; set; }

    /// <summary>
    /// Eşzamanlılık denetimi: iki kişi aynı kaydı aynı anda değiştirmeye çalışırsa ikincisi
    /// <c>DbUpdateConcurrencyException</c> alır (API'de 409). Teklif kabulünde çifte kabulü bu önler.
    /// </summary>
    public byte[] RowVersion { get; set; } = [];
}
