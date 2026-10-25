using System.Text.Json;
using System.Text.Json.Serialization;

namespace Yukum.Api.Json;

/// <summary>
/// API'nin JSON kuralları tek yerde: alan adları camelCase (varsayılan), enum'lar string ("InTransit"),
/// tarihler UTC ISO 8601 (<c>2026-10-20T10:15:00Z</c>). iOS'taki Codable modelleri bu sözleşmeye göre yazılır.
/// Hem controller cevapları hem hata cevapları (ProblemDetails) aynı kuralları kullansın diye iki yerde uygulanır.
/// </summary>
public static class JsonSetup
{
    /// <summary>Verilen JSON ayarlarına proje kurallarını ekler.</summary>
    public static void Configure(JsonSerializerOptions options)
    {
        // enum'lar sayı değil metin olarak gider (örn. "Shipper"). iOS'ta String enum ile eşleşir.
        options.Converters.Add(new JsonStringEnumConverter());
        // DateTimeOffset alanları UTC ISO 8601 yazılır/okunur.
        options.Converters.Add(new UtcDateTimeOffsetConverter());
        // DateTime alanları UTC ISO 8601 yazılır/okunur.
        options.Converters.Add(new UtcDateTimeConverter());
    }
}
