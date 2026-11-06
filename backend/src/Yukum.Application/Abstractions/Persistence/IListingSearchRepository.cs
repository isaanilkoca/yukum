using Yukum.Application.Common;
using Yukum.Application.Listings;
using Yukum.Domain.Accounts;
using Yukum.Domain.Listings;

namespace Yukum.Application.Abstractions.Persistence;

/// <summary>Açık ilan listesinin filtreleri (hepsi isteğe bağlı; null = koşul yok). CarrierId: bu taşımacının teklif verdiği ilanlar listeden çıkarılır.</summary>
public sealed record OpenListingFilter(
    Guid CarrierId, int? FromCityId, int? FromDistrictId, int? ToCityId,
    decimal? MinBudget, decimal? MaxBudget, VehicleType? VehicleType, DateOnly? PickupFrom, DateOnly? PickupTo);

/// <summary>Mesafe sıralaması için hafif özet: ilan numarası, kalkış yeri, oluşturulma zamanı (ilanın tamamı değil).</summary>
public sealed record ListingPoint(Guid Id, int FromCityId, int FromDistrictId, DateTime CreatedAt);

/// <summary>
/// Açık ilanları filtreleyip sayfalayan özel okuma sözleşmesi. Genel <see cref="IRepository{T}"/> hepsini belleğe çekerdi;
/// burada filtre, sıralama, sayfalama ve sayım veritabanında (SQL) yapılır.
/// </summary>
public interface IListingSearchRepository
{
    /// <summary>Filtreye uyan açık ilanların istenen sayfasını ve toplam sayısını getirir (Nearest dışındaki sıralamalar, SQL'de).</summary>
    Task<PagedResult<Listing>> SearchOpenAsync(OpenListingFilter filter, ListingSort sort, int page, int pageSize, CancellationToken cancellationToken = default);

    /// <summary>Filtreye uyan TÜM açık ilanların hafif özetini getirir (mesafe sıralaması için: sıralama bellekte, sonra yalnız sayfanın ilanları okunur).</summary>
    Task<IReadOnlyList<ListingPoint>> ListOpenPointsAsync(OpenListingFilter filter, CancellationToken cancellationToken = default);
}
