using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Time.Testing;
using Yukum.Domain.Geography;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Data;

// 81 il / 973 ilçe seed'inin doğruluğu. Doğru cevap anahtarı docs/veri/il-ilce.json'dur (karar K-013).
[Collection("SqlServer")]
public class GeographySeedTests(SqlServerFixture sql)
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 25, 9, 0, 0, TimeSpan.Zero);

    // Yalnız okuyan testler aynı veritabanını paylaşır (her test için 1054 satırı yeniden yazmamak için).
    private static readonly SemaphoreSlim Gate = new(1, 1);
    private static TestDatabase? _shared;

    private async Task<TestDatabase> SharedAsync()
    {
        await Gate.WaitAsync();
        try
        {
            return _shared ??= await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));
        }
        finally
        {
            Gate.Release();
        }
    }

    [Fact]
    public async Task Seed_has_81_cities_and_973_districts()
    {
        await using var context = (await SharedAsync()).NewContext();

        Assert.Equal(81, await context.Set<City>().CountAsync());
        Assert.Equal(973, await context.Set<District>().CountAsync());
    }

    [Fact]
    public async Task City_ids_are_the_plate_codes_1_to_81()
    {
        await using var context = (await SharedAsync()).NewContext();

        var ids = await context.Set<City>().OrderBy(c => c.Id).Select(c => c.Id).ToListAsync();

        Assert.Equal(Enumerable.Range(1, 81), ids);
    }

    [Theory]
    [InlineData(1, "Adana")]
    [InlineData(6, "Ankara")]
    [InlineData(33, "Mersin")]
    [InlineData(34, "İstanbul")]
    [InlineData(42, "Konya")]
    [InlineData(64, "Uşak")]
    [InlineData(81, "Düzce")]
    public async Task Well_known_plate_codes_match_their_city(int plate, string name)
    {
        await using var context = (await SharedAsync()).NewContext();

        var city = await context.Set<City>().SingleAsync(c => c.Id == plate);

        Assert.Equal(name, city.Name);
    }

    [Fact]
    public async Task Every_city_matches_the_seed_file_exactly()
    {
        await using var context = (await SharedAsync()).NewContext();

        var actual = await context.Set<City>().OrderBy(c => c.Id).ToListAsync();
        var expected = GeographySeedFile.Cities.OrderBy(c => c.Plate).ToList();

        Assert.Equal(expected.Count, actual.Count);
        for (var i = 0; i < expected.Count; i++)
        {
            Assert.Equal(expected[i].Plate, actual[i].Id);
            Assert.Equal(expected[i].Name, actual[i].Name);
            Assert.Equal(expected[i].Lat, actual[i].Latitude);
            Assert.Equal(expected[i].Lon, actual[i].Longitude);
        }
    }

    [Fact]
    public async Task Every_district_matches_the_seed_file_with_ids_in_plate_then_file_order()
    {
        await using var context = (await SharedAsync()).NewContext();

        var actual = await context.Set<District>().OrderBy(d => d.Id).ToListAsync();

        // Beklenen: plaka sırası, sonra dosyadaki (Türkçe alfabetik) sıra; numaralar 1'den başlayıp ardışık.
        var expected = GeographySeedFile.Cities
            .OrderBy(c => c.Plate)
            .SelectMany(c => c.Districts.Select(d => (c.Plate, District: d)))
            .Select((x, index) => (Id: index + 1, x.Plate, x.District))
            .ToList();

        Assert.Equal(expected.Count, actual.Count);
        for (var i = 0; i < expected.Count; i++)
        {
            Assert.Equal(expected[i].Id, actual[i].Id);
            Assert.Equal(expected[i].Plate, actual[i].CityId);
            Assert.Equal(expected[i].District.Name, actual[i].Name);
            Assert.Equal(expected[i].District.Lat, actual[i].Latitude);
            Assert.Equal(expected[i].District.Lon, actual[i].Longitude);
        }
    }

    [Fact]
    public async Task District_ids_are_frozen_first_is_Aladag_of_Adana_last_is_the_973rd()
    {
        await using var context = (await SharedAsync()).NewContext();

        var first = await context.Set<District>().SingleAsync(d => d.Id == 1);
        var last = await context.Set<District>().OrderByDescending(d => d.Id).FirstAsync();

        Assert.Equal("Aladağ", first.Name);
        Assert.Equal(1, first.CityId);
        Assert.Equal(973, last.Id);
        Assert.Equal(81, last.CityId);
    }

    [Fact]
    public async Task Each_city_has_the_district_count_given_in_the_seed_file()
    {
        await using var context = (await SharedAsync()).NewContext();

        var counts = await context.Set<District>()
            .GroupBy(d => d.CityId)
            .Select(g => new { CityId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.CityId, x => x.Count);

        foreach (var city in GeographySeedFile.Cities)
        {
            Assert.Equal(city.Districts.Count, counts[city.Plate]);
        }
    }

    [Fact]
    public async Task Every_district_belongs_to_an_existing_city_and_loads_it()
    {
        await using var context = (await SharedAsync()).NewContext();

        var districts = await context.Set<District>().Include(d => d.City).ToListAsync();

        Assert.Equal(973, districts.Count);
        Assert.All(districts, d => Assert.Equal(d.CityId, d.City.Id));
    }

    [Fact]
    public async Task Konya_Meram_exists_and_the_name_Merkez_repeats_across_cities()
    {
        await using var context = (await SharedAsync()).NewContext();

        Assert.True(await context.Set<District>().AnyAsync(d => d.CityId == 42 && d.Name == "Meram"));
        Assert.True(await context.Set<District>().Where(d => d.Name == "Merkez").Select(d => d.CityId).Distinct().CountAsync() > 1);
    }

    [Fact]
    public async Task Duplicate_district_name_in_the_same_city_is_rejected()
    {
        var db = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));
        await using var context = db.NewContext();

        context.Set<District>().Add(new District { Id = 2000, CityId = 42, Name = "Meram", Latitude = 0, Longitude = 0 });

        await Assert.ThrowsAsync<DbUpdateException>(() => context.SaveChangesAsync());
    }

    [Fact]
    public async Task Duplicate_city_name_is_rejected()
    {
        var db = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));
        await using var context = db.NewContext();

        context.Set<City>().Add(new City { Id = 100, Name = "Konya", Latitude = 0, Longitude = 0 });

        await Assert.ThrowsAsync<DbUpdateException>(() => context.SaveChangesAsync());
    }

    [Fact]
    public async Task A_district_cannot_point_to_a_missing_city()
    {
        var db = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));
        await using var context = db.NewContext();

        context.Set<District>().Add(new District { Id = 2000, CityId = 999, Name = "Hayali", Latitude = 0, Longitude = 0 });

        await Assert.ThrowsAsync<DbUpdateException>(() => context.SaveChangesAsync());
    }
}
