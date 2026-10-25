namespace Yukum.Application.Abstractions.Persistence;

/// <summary>
/// "Çalışma birimi": bir kullanım senaryosunda birden çok kayıtta yapılan değişiklikleri TEK işlemde (transaction) kaydeder.
/// Ya hepsi kaydolur ya hiçbiri. Örn. teklif kabulünde "teklif kabul + diğerleri ret + ilan atandı" birlikte yazılır.
/// </summary>
public interface IUnitOfWork
{
    /// <summary>Bekleyen tüm değişiklikleri veritabanına yazar.</summary>
    /// <returns>Etkilenen satır sayısı.</returns>
    /// <remarks>Kayıt arada başkası tarafından değiştirilmişse (RowVersion çakışması) <c>DbUpdateConcurrencyException</c> fırlar; API bunu 409'a çevirecek.</remarks>
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
