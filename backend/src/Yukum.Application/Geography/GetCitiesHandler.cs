using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;

namespace Yukum.Application.Geography;

/// <summary>"Tüm illeri getir" sorgusunu işler: depodan illeri alır, istemciye gidecek biçime (<see cref="CityDto"/>) çevirir.</summary>
public sealed class GetCitiesHandler(IGeographyRepository geography)
    : IQueryHandler<GetCitiesQuery, IReadOnlyList<CityDto>>
{
    /// <summary>81 ili plaka koduna göre sıralı döndürür.</summary>
    public async Task<IReadOnlyList<CityDto>> HandleAsync(GetCitiesQuery query, CancellationToken cancellationToken = default)
    {
        // Depodan 81 ili al (ilk istekten sonra önbellekten gelir).
        var cities = await geography.ListCitiesAsync(cancellationToken);
        // Veritabanı varlığını (City) istemciye giden sade modele (CityDto: yalnız id ve name) çevir. Koordinatlar dışarı çıkmaz.
        return cities.Select(c => new CityDto(c.Id, c.Name)).ToList();
    }
}
