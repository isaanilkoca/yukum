using System.Text.Json;

namespace Yukum.IntegrationTests.Support;

// Testin "doğru cevap anahtarı": docs/veri/il-ilce.json dosyasını okur. Veritabanındaki seed bununla birebir karşılaştırılır.
public static class GeographySeedFile
{
    public sealed record CityRow(int Plate, string Name, double Lat, double Lon, List<DistrictRow> Districts);

    public sealed record DistrictRow(string Name, double Lat, double Lon);

    private static readonly Lazy<List<CityRow>> Cached = new(Load);

    public static List<CityRow> Cities => Cached.Value;

    private static List<CityRow> Load()
    {
        // Test çıktı klasöründen yukarı çıkarak depo kökündeki docs/veri/il-ilce.json'u bulur.
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            var path = Path.Combine(directory.FullName, "docs", "veri", "il-ilce.json");
            if (File.Exists(path))
            {
                var json = File.ReadAllText(path);
                return JsonSerializer.Deserialize<List<CityRow>>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;
            }

            directory = directory.Parent;
        }

        throw new FileNotFoundException("docs/veri/il-ilce.json bulunamadı.");
    }
}
