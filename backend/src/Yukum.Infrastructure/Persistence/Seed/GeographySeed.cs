using System.Reflection;
using System.Text.Json;
using Yukum.Domain.Geography;

namespace Yukum.Infrastructure.Persistence.Seed;

/// <summary>
/// 81 il ve 973 ilçenin başlangıç verisini <c>docs/veri/il-ilce.json</c> dosyasından okur.
/// Dosya derleme sırasında Infrastructure assembly'sinin içine gömülür; çalışırken ayrı dosya aranmaz.
/// Veri tek kaynaktan gelir (koda kopyalanmaz), böylece veri ile kod birbirinden ayrışmaz.
/// </summary>
public static class GeographySeed
{
    private const string ResourceName = "Yukum.Infrastructure.il-ilce.json";

    // Lazy: dosya ilk kullanıldığında bir kez okunur, sonra hazır durur.
    private static readonly Lazy<(List<City> Cities, List<District> Districts)> Data = new(Load);

    /// <summary>81 il; <c>Id</c> plaka kodudur (1–81).</summary>
    public static IReadOnlyList<City> Cities => Data.Value.Cities;

    /// <summary>973 ilçe; <c>Id</c> plaka sırası, sonra dosyadaki (Türkçe alfabetik) sıraya göre 1'den başlayıp ardışık verilir (karar K-013).</summary>
    public static IReadOnlyList<District> Districts => Data.Value.Districts;

    private static (List<City>, List<District>) Load()
    {
        // JSON dosyası derleme sırasında dll'in İÇİNE gömülmüştü (csproj'daki EmbeddedResource); çalışırken diskte dosya aranmaz.
        using var stream = typeof(GeographySeed).Assembly.GetManifestResourceStream(ResourceName)
            ?? throw new InvalidOperationException($"Gömülü kaynak bulunamadı: {ResourceName}");

        // JSON → C# nesneleri. PropertyNameCaseInsensitive: JSON'daki 'plate' ile C#'taki Plate eşleşir.
        var rows = JsonSerializer.Deserialize<List<CityRow>>(stream, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
            ?? throw new InvalidOperationException("il-ilce.json okunamadı.");

        var cities = new List<City>();
        var districts = new List<District>();
        // İlçe numaraları 1'den başlayıp ardışık verilir (K-013).
        var nextDistrictId = 1;

        // İlleri plaka sırasıyla gez; ilçe numaraları bu sıraya göre verilir.
        foreach (var row in rows.OrderBy(r => r.Plate))
        {
            // İl: Id = plaka kodu.
            cities.Add(new City { Id = row.Plate, Name = row.Name, Latitude = row.Lat, Longitude = row.Lon });

            foreach (var district in row.Districts)
            {
                districts.Add(new District
                {
                    // Sıradaki numarayı ver, sonra bir artır.
                    Id = nextDistrictId++,
                    CityId = row.Plate,
                    Name = district.Name,
                    Latitude = district.Lat,
                    Longitude = district.Lon
                });
            }
        }

        return (cities, districts);
    }

    // JSON dosyasındaki satır biçimi (yalnız okumak için).
    private sealed record CityRow(int Plate, string Name, double Lat, double Lon, List<DistrictRow> Districts);

    private sealed record DistrictRow(string Name, double Lat, double Lon);
}
