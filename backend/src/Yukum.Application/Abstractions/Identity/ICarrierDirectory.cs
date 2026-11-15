namespace Yukum.Application.Abstractions.Identity;

/// <summary>Taşımacı profilinin özeti (ad + puan bilgileri).</summary>
public sealed record CarrierSummary(Guid UserId, string FullName, string? About, decimal AverageRating, int RatingCount, int CompletedJobCount,
    string? AvatarUrl = null, int? HomeCityId = null, DateTime MemberSince = default); // 15 Kasım (8. adım): profilde fotoğraf, il, üyelik tarihi

/// <summary>Taşımacı profil bilgisini okur ve puan/iş sayacını günceller. Uygulama katmanı EF'e dokunmaz, bu sözleşmeyle konuşur.</summary>
public interface ICarrierDirectory
{
    /// <summary>Numaralara karşılık gelen Taşımacı özetleri (Taşımacı olmayan numara sözlükte yer almaz).</summary>
    Task<Dictionary<Guid, CarrierSummary>> GetSummariesAsync(IEnumerable<Guid> carrierIds, CancellationToken cancellationToken = default);

    /// <summary>Puan ortalamasını ve puan sayısını ATOMİK günceller (tek SQL UPDATE; iki puan aynı anda gelse de kayıp olmaz).</summary>
    Task AddRatingAsync(Guid carrierId, int rating, CancellationToken cancellationToken = default);

    /// <summary>Tamamlanan iş sayısını bir artırır (atomik).</summary>
    Task AddCompletedJobAsync(Guid carrierId, CancellationToken cancellationToken = default);
}
