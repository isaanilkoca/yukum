using System.Text.Json;
using System.Text.Json.Serialization;

namespace Yukum.Api.Json;

// Tek yerde tanımlanan JSON kuralları: camelCase (varsayılan), enum = string, tarih = UTC ISO 8601.
// Hem controller cevapları hem ProblemDetails aynı kuralları kullansın diye iki yerde de uygulanır.
public static class JsonSetup
{
    public static void Configure(JsonSerializerOptions options)
    {
        options.Converters.Add(new JsonStringEnumConverter());
        options.Converters.Add(new UtcDateTimeOffsetConverter());
        options.Converters.Add(new UtcDateTimeConverter());
    }
}
