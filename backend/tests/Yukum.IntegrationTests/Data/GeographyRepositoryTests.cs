using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Time.Testing;
using Yukum.Infrastructure.Persistence;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Data;

// İl/ilçe okuma deposu: gerçek SQL Server'a karşı, sıralama ve önbellek davranışı.
[Collection("SqlServer")]
public class GeographyRepositoryTests(SqlServerFixture sql)
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 25, 9, 0, 0, TimeSpan.Zero);

    private static GeographyRepository NewRepository(TestDatabase db, IMemoryCache cache) => new(db.NewContext(), cache);

    private static MemoryCache NewCache() => new(new MemoryCacheOptions());

    [Fact]
    public async Task ListCities_returns_81_cities_ordered_by_plate_code()
    {
        var db = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));

        var cities = await NewRepository(db, NewCache()).ListCitiesAsync();

        Assert.Equal(Enumerable.Range(1, 81), cities.Select(c => c.Id));
        Assert.Equal("Adana", cities[0].Name);
    }

    [Fact]
    public async Task ListDistricts_returns_the_districts_of_that_city_only_ordered_by_id()
    {
        var db = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));

        var districts = await NewRepository(db, NewCache()).ListDistrictsAsync(42);

        var expected = GeographySeedFile.Cities.Single(c => c.Plate == 42).Districts.Select(d => d.Name);
        Assert.Equal(expected, districts.Select(d => d.Name));
        Assert.All(districts, d => Assert.Equal(42, d.CityId));
        Assert.Equal(districts.OrderBy(d => d.Id).Select(d => d.Id), districts.Select(d => d.Id));
    }

    [Fact]
    public async Task ListDistricts_returns_empty_for_a_missing_city()
    {
        var db = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));

        Assert.Empty(await NewRepository(db, NewCache()).ListDistrictsAsync(999));
    }

    [Theory]
    [InlineData(1, true)]
    [InlineData(81, true)]
    [InlineData(0, false)]
    [InlineData(82, false)]
    [InlineData(-5, false)]
    public async Task CityExists_is_true_only_for_plate_codes_1_to_81(int cityId, bool expected)
    {
        var db = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));

        Assert.Equal(expected, await NewRepository(db, NewCache()).CityExistsAsync(cityId));
    }

    [Fact]
    public async Task Cities_are_cached_a_second_call_does_not_go_back_to_the_database()
    {
        var db = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));
        var cache = NewCache();
        Assert.Equal("Adana", (await NewRepository(db, cache).ListCitiesAsync())[0].Name);

        // Veritabanında adı gizlice değiştir; önbellek varsa eski ad gelmeye devam etmeli.
        await using (var context = db.NewContext())
            await context.Database.ExecuteSqlRawAsync("UPDATE Cities SET Name = N'DEĞİŞTİ' WHERE Id = 1");

        Assert.Equal("Adana", (await NewRepository(db, cache).ListCitiesAsync())[0].Name);
        // Önbelleksiz yeni bir depo ise güncel veriyi görür: değişikliğin gerçekten yapıldığını kanıtlar.
        Assert.Equal("DEĞİŞTİ", (await NewRepository(db, NewCache()).ListCitiesAsync())[0].Name);
    }

    [Fact]
    public async Task Districts_are_cached_per_city()
    {
        var db = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));
        var cache = NewCache();
        var first = await NewRepository(db, cache).ListDistrictsAsync(42);

        // Aynı ilde aynı ad olamayacağı için yalnız bir ilçenin adı değiştirilir.
        await using (var context = db.NewContext())
            await context.Database.ExecuteSqlRawAsync("UPDATE Districts SET Name = N'DEĞİŞTİ' WHERE CityId = 42 AND Name = N'Meram'");

        var cached = await NewRepository(db, cache).ListDistrictsAsync(42);
        Assert.Equal(first.Select(d => d.Name), cached.Select(d => d.Name));
        Assert.Contains("Meram", cached.Select(d => d.Name));
        // Önbelleksiz yeni bir depo güncel veriyi görür: değişikliğin gerçekten yapıldığını kanıtlar.
        Assert.Contains("DEĞİŞTİ", (await NewRepository(db, NewCache()).ListDistrictsAsync(42)).Select(d => d.Name));
        // Başka ilin önbelleği ayrıdır: 41'in ilçeleri etkilenmez ve ayrıca okunur.
        Assert.NotEmpty(await NewRepository(db, cache).ListDistrictsAsync(41));
    }
}
