using Yukum.Application.Vehicles;
using Yukum.Domain.Accounts;

namespace Yukum.UnitTests.Application;

// 15 Kasım: "Yalnız araçlarıma uygun" — büyük araç küçüğün işini de yapar; frigorifik soğuk zinciri yalnız o taşır.
public class VehicleCompatibilityTests
{
    [Theory]
    [InlineData(VehicleType.Truck, new[] { VehicleType.Truck, VehicleType.Lorry, VehicleType.Pickup, VehicleType.Car, VehicleType.Any })]
    [InlineData(VehicleType.Pickup, new[] { VehicleType.Pickup, VehicleType.Car, VehicleType.Any })]
    [InlineData(VehicleType.Car, new[] { VehicleType.Car, VehicleType.Any })]
    [InlineData(VehicleType.Refrigerated, new[] { VehicleType.Refrigerated, VehicleType.Lorry, VehicleType.Pickup, VehicleType.Car, VehicleType.Any })]
    [InlineData(VehicleType.Other, new[] { VehicleType.Other, VehicleType.Any })]
    public void A_vehicle_carries_its_own_and_smaller_loads(VehicleType vehicle, VehicleType[] expected) =>
        Assert.Equal(expected.Order(), VehicleCompatibility.ListingTypesFor([vehicle]).Order());

    [Fact]
    public void Only_a_refrigerated_vehicle_sees_cold_chain_and_several_vehicles_combine()
    {
        Assert.DoesNotContain(VehicleType.Refrigerated, VehicleCompatibility.ListingTypesFor([VehicleType.Truck]));
        var both = VehicleCompatibility.ListingTypesFor([VehicleType.Pickup, VehicleType.Refrigerated]);
        Assert.Contains(VehicleType.Refrigerated, both); Assert.Contains(VehicleType.Lorry, both); Assert.DoesNotContain(VehicleType.Truck, both);
        Assert.Equal([VehicleType.Any], VehicleCompatibility.ListingTypesFor([])); // aracı yok: yalnız "Farketmez"
    }
}
