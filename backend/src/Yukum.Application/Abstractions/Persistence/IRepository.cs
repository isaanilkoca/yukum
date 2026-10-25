using System.Linq.Expressions;
using Yukum.Domain.Common;

namespace Yukum.Application.Abstractions.Persistence;

/// <summary>
/// Veritabanındaki bir tablo için ince, genel veri erişimi ("şu kriterdeki kayıtları getir / ekle / sil").
/// İş kuralı kodu bu arayüzü bilir, SQL Server'ı veya EF Core'u bilmez; böylece testte sahte depo verilebilir.
/// <list type="bullet">
/// <item>Karmaşık sorgular (filtre, sayfalama, konum) ilgili özel repository'ye yazılır.</item>
/// <item>Değiştirilecek kayıt izlenerek alınır, değişiklik <see cref="IUnitOfWork.SaveChangesAsync"/> ile kaydedilir; ayrı bir Update gerekmez.</item>
/// <item>Yumuşak silinmiş (IsDeleted) kayıtlar hiçbir metotta dönmez.</item>
/// </list>
/// </summary>
/// <typeparam name="T">Tablo varlığı (<see cref="BaseEntity"/>'den türer).</typeparam>
// T yalnız BaseEntity'den türeyen tablolar olabilir. 'Update' bilerek yok: izlenen kayıt değişince SaveChanges kendiliğinden kaydeder.
public interface IRepository<T> where T : BaseEntity
{
    /// <summary>Numarasına göre tek kayıt getirir.</summary>
    /// <param name="id">Kayıt numarası.</param>
    /// <param name="asNoTracking">Yalnız okunacaksa true verin (daha hızlı); değiştirilecekse false bırakın.</param>
    /// <param name="cancellationToken">İşlemi yarıda kesmek için (örn. istemci isteği iptal ettiğinde).</param>
    /// <returns>Kayıt; yoksa ya da silinmişse <c>null</c>.</returns>
    // Tek kayıt. 'T?' = bulunamazsa null dönebilir. asNoTracking: yalnız okunacaksa true (daha hızlı).
    Task<T?> GetByIdAsync(Guid id, bool asNoTracking = false, CancellationToken cancellationToken = default);

    /// <summary>Koşula uyan kayıtları listeler; koşul verilmezse hepsini (silinmemiş olanları) getirir.</summary>
    /// <param name="predicate">Süzgeç, örn. <c>x => x.Name == "a"</c>. Veritabanında çalışır, bellekte değil.</param>
    /// <param name="asNoTracking">Yalnız okunacaksa true verin (daha hızlı); değiştirilecekse false bırakın.</param>
    /// <param name="cancellationToken">İşlemi yarıda kesmek için.</param>
    // predicate: 'şu koşula uyanlar' (örn. x => x.Name == "a"); verilmezse hepsi. Koşul SQL'e (WHERE) çevrilir, bellekte süzülmez.
    Task<IReadOnlyList<T>> ListAsync(
        Expression<Func<T, bool>>? predicate = null, bool asNoTracking = false, CancellationToken cancellationToken = default);

    /// <summary>Koşula uyan en az bir kayıt var mı?</summary>
    // En az bir kayıt koşula uyuyor mu? (SQL: EXISTS)
    Task<bool> AnyAsync(Expression<Func<T, bool>> predicate, CancellationToken cancellationToken = default);

    /// <summary>Koşula uyan kayıt sayısı; koşul verilmezse silinmemiş tüm kayıtların sayısı.</summary>
    // Kaç kayıt var? (SQL: COUNT)
    Task<int> CountAsync(Expression<Func<T, bool>>? predicate = null, CancellationToken cancellationToken = default);

    /// <summary>Yeni kaydı ekler. Veritabanına <see cref="IUnitOfWork.SaveChangesAsync"/> çağrılınca yazılır.</summary>
    // Ekle: veritabanına henüz yazılmaz, IUnitOfWork.SaveChangesAsync çağrılınca yazılır.
    void Add(T entity);

    /// <summary>Kaydı SİLMEZ; <c>IsDeleted = true</c> yapar (yumuşak silme, <c>AppDbContext</c> uygular).</summary>
    // Sil: gerçekte silinmez, IsDeleted = true yapılır (yumuşak silme), kayıt sorgulardan gizlenir.
    void Remove(T entity);
}
