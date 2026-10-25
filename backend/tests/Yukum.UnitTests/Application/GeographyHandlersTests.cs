using NSubstitute;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Application.Geography;
using Yukum.Domain.Geography;

namespace Yukum.UnitTests.Application;

// İl/ilçe sorgu handler'ları: sahte depo ile, veritabanı olmadan.
public class GeographyHandlersTests
{
    private readonly IGeographyRepository _geography = Substitute.For<IGeographyRepository>();

    [Fact]
    public async Task GetCities_maps_cities_to_id_and_name_only_in_the_given_order()
    {
        _geography.ListCitiesAsync(Arg.Any<CancellationToken>()).Returns(
        [
            new City { Id = 1, Name = "Adana", Latitude = 36.9, Longitude = 35.3 },
            new City { Id = 2, Name = "Adıyaman", Latitude = 37.7, Longitude = 38.2 }
        ]);

        var result = await new GetCitiesHandler(_geography).HandleAsync(new GetCitiesQuery());

        Assert.Equal([new CityDto(1, "Adana"), new CityDto(2, "Adıyaman")], result);
    }

    [Fact]
    public async Task GetDistricts_maps_districts_of_an_existing_city()
    {
        _geography.CityExistsAsync(42, Arg.Any<CancellationToken>()).Returns(true);
        _geography.ListDistrictsAsync(42, Arg.Any<CancellationToken>()).Returns(
        [
            new District { Id = 10, CityId = 42, Name = "Ahırlı" },
            new District { Id = 11, CityId = 42, Name = "Akören" }
        ]);

        var result = await new GetDistrictsHandler(_geography).HandleAsync(new GetDistrictsQuery(42));

        Assert.Equal([new DistrictDto(10, "Ahırlı"), new DistrictDto(11, "Akören")], result);
    }

    [Fact]
    public async Task GetDistricts_throws_NotFound_for_a_missing_city_and_never_lists_districts()
    {
        _geography.CityExistsAsync(999, Arg.Any<CancellationToken>()).Returns(false);

        var error = await Assert.ThrowsAsync<NotFoundException>(
            () => new GetDistrictsHandler(_geography).HandleAsync(new GetDistrictsQuery(999)));

        Assert.Equal("İl bulunamadı.", error.Message);
        await _geography.DidNotReceive().ListDistrictsAsync(Arg.Any<int>(), Arg.Any<CancellationToken>());
    }
}
