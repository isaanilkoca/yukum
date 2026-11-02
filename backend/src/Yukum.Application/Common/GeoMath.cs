namespace Yukum.Application.Common;

/// <summary>Konum hesapları. Dünya küre olduğu için iki nokta arası mesafe düz cetvelle değil Haversine formülüyle bulunur.</summary>
public static class GeoMath
{
    private const double EarthRadiusKm = 6371.0088; // dünyanın ortalama yarıçapı, kilometre

    /// <summary>İki enlem/boylam noktası arasındaki kuş uçuşu mesafe (km). Yol mesafesi değil, doğrusal mesafedir.</summary>
    public static double DistanceKm(double lat1, double lon1, double lat2, double lon2)
    {
        // Dereceyi radyana çevir (trigonometri radyanla çalışır): derece × π / 180.
        static double Rad(double degrees) => degrees * Math.PI / 180.0;

        var dLat = Rad(lat2 - lat1);
        var dLon = Rad(lon2 - lon1);

        // Haversine: a = sin²(Δlat/2) + cos(lat1)·cos(lat2)·sin²(Δlon/2)
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(Rad(lat1)) * Math.Cos(Rad(lat2)) * Math.Sin(dLon / 2) * Math.Sin(dLon / 2);

        // c = 2·atan2(√a, √(1−a)) = iki nokta arasındaki merkez açı (radyan) | mesafe = yarıçap × açı
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return EarthRadiusKm * c;
    }
}
