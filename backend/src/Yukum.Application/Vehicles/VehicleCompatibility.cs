using Yukum.Domain.Accounts;

namespace Yukum.Application.Vehicles;

// ┌─ BAĞLANTI HARİTASI: VehicleCompatibility.cs (15 Kasım) ──────────────────────
// │ KULLANAN : Application/Listings/ListingHandlers.cs → GetOpenListingsHandler ("Yalnız araçlarıma uygun" anahtarı, matchMyVehicles=true)
// │ SONUÇ    : Taşımacı'nın araçlarına UYGUN ilan türleri → OpenListingFilter.AllowedVehicleTypes → SQL: AND l.VehicleType IN (...)
// │ TEST     : tests/Yukum.UnitTests/Application/VehicleCompatibilityTests.cs
// └──────────────────────────────────────────────────────────────────────
// KURAL (kullanıcı onayı): BÜYÜK ARAÇ KÜÇÜĞÜN İŞİNİ DE YAPAR — birebir eşleşme gerçekçi değildi (kamyonet işini tır da taşır).
//   Tır ⊇ Kamyon ⊇ Kamyonet ⊇ Otomobil.
//   Frigorifik: soğuk zinciri yalnız o taşır; soğutma kapalıyken normal kamyon gibi de çalışır → Frigorifik + Kamyon + Kamyonet + Otomobil.
//   "Diğer" yalnız "Diğer" ilanlarını görür (ne olduğu belli değil). "Farketmez" (Any) ilanı HER araca uygundur.
// NEDEN Application'da (SQL'de değil): kural iş kuralıdır, birim testle sınanır; SQL'e yalnız sonuç (tür listesi) gider.

/// <summary>Hangi araç hangi ilan türünü taşıyabilir.</summary>
public static class VehicleCompatibility
{
    private static readonly Dictionary<VehicleType, VehicleType[]> CanCarry = new()
    {
        [VehicleType.Truck] = [VehicleType.Truck, VehicleType.Lorry, VehicleType.Pickup, VehicleType.Car],
        [VehicleType.Lorry] = [VehicleType.Lorry, VehicleType.Pickup, VehicleType.Car],
        [VehicleType.Pickup] = [VehicleType.Pickup, VehicleType.Car],
        [VehicleType.Car] = [VehicleType.Car],
        [VehicleType.Refrigerated] = [VehicleType.Refrigerated, VehicleType.Lorry, VehicleType.Pickup, VehicleType.Car],
        [VehicleType.Other] = [VehicleType.Other],
    };

    /// <summary>Araç türlerine uygun ilan türleri ("Farketmez" her zaman dahil). Araç yoksa yalnız "Farketmez".</summary>
    public static IReadOnlyCollection<VehicleType> ListingTypesFor(IEnumerable<VehicleType> vehicleTypes) =>
        vehicleTypes.SelectMany(t => CanCarry.GetValueOrDefault(t, [t])).Append(VehicleType.Any).ToHashSet();
}
