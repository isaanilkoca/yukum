using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;

namespace Yukum.Application.Geography;

/// <summary>"Bir ilin ilçelerini getir" sorgusunu işler. İl yoksa <see cref="NotFoundException"/> fırlatır (API'de 404).</summary>
public sealed class GetDistrictsHandler(IGeographyRepository geography)
    : IQueryHandler<GetDistrictsQuery, IReadOnlyList<DistrictDto>>
{
    /// <summary>İlin ilçelerini sıralı döndürür; il yoksa "İl bulunamadı." hatası verir.</summary>
    public async Task<IReadOnlyList<DistrictDto>> HandleAsync(GetDistrictsQuery query, CancellationToken cancellationToken = default)
    {
        // Önce il var mı? Yoksa NotFoundException fırlat (→ 404). İlçe sorgusuna hiç gidilmez.
        if (!await geography.CityExistsAsync(query.CityId, cancellationToken))
            throw new NotFoundException("İl bulunamadı.");

        // İlin ilçelerini al (Türkçe alfabetik sıralı, önbellekli).
        var districts = await geography.ListDistrictsAsync(query.CityId, cancellationToken);
        // Sade modele çevir (DistrictDto: id, name).
        return districts.Select(d => new DistrictDto(d.Id, d.Name)).ToList();
    }
}
