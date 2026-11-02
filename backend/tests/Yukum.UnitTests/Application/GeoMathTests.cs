using Yukum.Application.Common;

namespace Yukum.UnitTests.Application;

// Haversine mesafe hesabı: bilinen şehir çiftleriyle doğrulanır.
public class GeoMathTests
{
    [Fact]
    public void Same_point_is_zero_km()
    {
        Assert.Equal(0, GeoMath.DistanceKm(36.8, 34.64, 36.8, 34.64), 6);
    }

    [Fact]
    public void Istanbul_to_Ankara_is_about_350_km_in_a_straight_line()
    {
        var km = GeoMath.DistanceKm(41.0082, 28.9784, 39.9334, 32.8597);   // İstanbul → Ankara
        Assert.InRange(km, 340, 360);
    }

    [Fact]
    public void Distance_is_the_same_in_both_directions()
    {
        var a = GeoMath.DistanceKm(36.8, 34.64, 41.01, 28.98);
        var b = GeoMath.DistanceKm(41.01, 28.98, 36.8, 34.64);
        Assert.Equal(a, b, 6);
    }

    [Fact]
    public void Nearer_point_gives_a_smaller_distance()
    {
        // İstanbul'dan Edirne, Mersin'den daha yakın.
        var toEdirne = GeoMath.DistanceKm(41.0, 29.0, 41.67, 26.56);
        var toMersin = GeoMath.DistanceKm(41.0, 29.0, 36.8, 34.64);
        Assert.True(toEdirne < toMersin);
    }
}
