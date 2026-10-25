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
public interface IRepository<T> where T : BaseEntity
{
    /// <summary>Numarasına göre tek kayıt getirir.</summary>
    /// <param name="id">Kayıt numarası.</param>
    /// <param name="asNoTracking">Yalnız okunacaksa true verin (daha hızlı); değiştirilecekse false bırakın.</param>
    /// <param name="cancellationToken">İşlemi yarıda kesmek için (örn. istemci isteği iptal ettiğinde).</param>
    /// <returns>Kayıt; yoksa ya da silinmişse <c>null</c>.</returns>
    Task<T?> GetByIdAsync(Guid id, bool asNoTracking = false, CancellationToken cancellationToken = default);

    /// <summary>Koşula uyan kayıtları listeler; koşul verilmezse hepsini (silinmemiş olanları) getirir.</summary>
    /// <param name="predicate">Süzgeç, örn. <c>x => x.Name == "a"</c>. Veritabanında çalışır, bellekte değil.</param>
    /// <param name="asNoTracking">Yalnız okunacaksa true verin (daha hızlı); değiştirilecekse false bırakın.</param>
    /// <param name="cancellationToken">İşlemi yarıda kesmek için.</param>
    Task<IReadOnlyList<T>> ListAsync(
        Expression<Func<T, bool>>? predicate = null, bool asNoTracking = false, CancellationToken cancellationToken = default);

    /// <summary>Koşula uyan en az bir kayıt var mı?</summary>
    Task<bool> AnyAsync(Expression<Func<T, bool>> predicate, CancellationToken cancellationToken = default);

    /// <summary>Koşula uyan kayıt sayısı; koşul verilmezse silinmemiş tüm kayıtların sayısı.</summary>
    Task<int> CountAsync(Expression<Func<T, bool>>? predicate = null, CancellationToken cancellationToken = default);

    /// <summary>Yeni kaydı ekler. Veritabanına <see cref="IUnitOfWork.SaveChangesAsync"/> çağrılınca yazılır.</summary>
    void Add(T entity);

    /// <summary>Kaydı SİLMEZ; <c>IsDeleted = true</c> yapar (yumuşak silme, <c>AppDbContext</c> uygular).</summary>
    void Remove(T entity);
}
