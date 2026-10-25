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
        var cities = await geography.ListCitiesAsync(cancellationToken);
        return cities.Select(c => new CityDto(c.Id, c.Name)).ToList();
    }
}
