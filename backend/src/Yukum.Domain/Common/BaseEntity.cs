namespace Yukum.Domain.Common;

// Tüm tabloların ortak alanları. Domain katmanı hiçbir pakete bağlı değildir.
public abstract class BaseEntity
{
    // Boş gelir; EF Core, SQL Server için sıralı GUID'i kaydederken üretir.
    public Guid Id { get; protected set; }

    // UTC. AppDbContext.SaveChanges tarafından doldurulur.
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }

    // Yumuşak silme: kayıt silinmez, işaretlenir; sorgularda varsayılan olarak gizlenir.
    public bool IsDeleted { get; set; }

    // İyimser eşzamanlılık: iki kişi aynı kaydı aynı anda değiştirirse ikincisi DbUpdateConcurrencyException alır.
    public byte[] RowVersion { get; set; } = [];
}
