using Yukum.Domain.Geography;

namespace Yukum.Application.Abstractions.Persistence;

/// <summary>
/// İl ve ilçe verisini okuma sözleşmesi. İl/ilçe sabit referans verisi olduğu için (GUID Id'li <c>BaseEntity</c> değil)
/// genel <see cref="IRepository{T}"/> yerine bu özel, yalnız-okuma repository kullanılır.
/// </summary>
public interface IGeographyRepository
{
    /// <summary>81 ili plaka koduna (Id) göre artan sırada getirir.</summary>
    /// <param name="cancellationToken">İşlemi yarıda kesmek için.</param>
    Task<IReadOnlyList<City>> ListCitiesAsync(CancellationToken cancellationToken = default);

    /// <summary>Verilen plaka koduyla bir il var mı?</summary>
    /// <param name="cityId">İlin plaka kodu.</param>
    /// <param name="cancellationToken">İşlemi yarıda kesmek için.</param>
    Task<bool> CityExistsAsync(int cityId, CancellationToken cancellationToken = default);

    /// <summary>Bir ilin ilçelerini Id'ye göre (yani Türkçe alfabetik) sırada getirir. İl yoksa boş liste döner.</summary>
    /// <param name="cityId">İlin plaka kodu.</param>
    /// <param name="cancellationToken">İşlemi yarıda kesmek için.</param>
    Task<IReadOnlyList<District>> ListDistrictsAsync(int cityId, CancellationToken cancellationToken = default);
}
