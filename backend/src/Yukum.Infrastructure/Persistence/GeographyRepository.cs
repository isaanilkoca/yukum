using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Domain.Geography;

namespace Yukum.Infrastructure.Persistence;

/// <summary>
/// <see cref="IGeographyRepository"/>'nin EF Core gerçeği. İl/ilçe verisi nadiren değiştiği için sonuçlar
/// <c>IMemoryCache</c>'te saklanır; aynı liste için veritabanına tekrar gidilmez (rapor: "cache'lenir").
/// Veri yalnız migration/yeni sürümle değiştiği için 24 saatlik süre yeterlidir.
/// </summary>
public sealed class GeographyRepository(AppDbContext context, IMemoryCache cache) : IGeographyRepository
{
    // Önbellek süresi: 24 saat (veri yalnız migration/yeni sürümle değişir).
    private static readonly TimeSpan CacheLifetime = TimeSpan.FromHours(24);
    private const string CitiesKey = "geography:cities";

    private static string DistrictsKey(int cityId) => $"geography:districts:{cityId}";

    /// <inheritdoc />
    public async Task<IReadOnlyList<City>> ListCitiesAsync(CancellationToken cancellationToken = default)
    {
        // Önbellekte var mı? Varsa veritabanına hiç gitmeden döndür.
        if (cache.TryGetValue(CitiesKey, out IReadOnlyList<City>? cached) && cached is not null)
            return cached;

        // AsNoTracking: yalnız okunuyor; takip edilmeyen kayıt önbellekte güvenle paylaşılır.
        IReadOnlyList<City> cities = await context.Cities.AsNoTracking().OrderBy(c => c.Id).ToListAsync(cancellationToken);
        // Sonraki istekler için önbelleğe koy.
        cache.Set(CitiesKey, cities, CacheLifetime);
        return cities;
    }

    /// <inheritdoc />
    public async Task<bool> CityExistsAsync(int cityId, CancellationToken cancellationToken = default) =>
        // İl var mı? 81 elemanlık (önbellekteki) listeye bakılır, ayrıca SQL gerekmez.
        (await ListCitiesAsync(cancellationToken)).Any(c => c.Id == cityId);

    /// <inheritdoc />
    public async Task<IReadOnlyList<District>> ListDistrictsAsync(int cityId, CancellationToken cancellationToken = default)
    {
        // Her ilin ilçeleri ayrı anahtarla saklanır.
        var key = DistrictsKey(cityId);
        if (cache.TryGetValue(key, out IReadOnlyList<District>? cached) && cached is not null)
            return cached;

        IReadOnlyList<District> districts = await context.Districts.AsNoTracking()
            // SQL: WHERE CityId = @cityId
            .Where(d => d.CityId == cityId)
            // Id sırası = Türkçe alfabetik sıra (seed öyle numaralandı, K-013).
            .OrderBy(d => d.Id)
            .ToListAsync(cancellationToken);

        // Boş sonuç önbelleğe alınmaz: anonim bir uca rastgele numaralar göndererek belleği şişirmek mümkün olmasın.
        if (districts.Count > 0)
            cache.Set(key, districts, CacheLifetime);

        return districts;
    }
}
