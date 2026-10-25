using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Yukum.Api.Json;

/// <summary>
/// Tarih sözleşmesinin ortak kuralı. Yazarken daima UTC <c>2026-10-20T10:15:00Z</c> (kesirli saniye YOK, çünkü
/// Swift'in <c>.iso8601</c> çözücüsü kesirli saniyeyi okuyamaz). Okurken ofsetli her ISO 8601 girdisi kabul edilir ve
/// UTC'ye çevrilir; ofseti olmayan girdi UTC sayılır; anlamsız girdi hata verir (API'de 400).
/// </summary>
internal static class UtcFormat
{
    private const string Pattern = "yyyy-MM-dd'T'HH:mm:ss'Z'";

    public static string Write(DateTime utc) => utc.ToString(Pattern, CultureInfo.InvariantCulture);

    public static DateTimeOffset Read(ref Utf8JsonReader reader)
    {
        var text = reader.GetString();
        if (DateTimeOffset.TryParse(text, CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var value))
            return value;

        throw new JsonException("Tarih ISO 8601 biçiminde olmalıdır (örn. 2026-10-20T10:15:00Z).");
    }
}

/// <summary><see cref="DateTimeOffset"/> alanları için UTC ISO 8601 dönüştürücüsü.</summary>
public sealed class UtcDateTimeOffsetConverter : JsonConverter<DateTimeOffset>
{
    public override DateTimeOffset Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) =>
        UtcFormat.Read(ref reader);

    public override void Write(Utf8JsonWriter writer, DateTimeOffset value, JsonSerializerOptions options) =>
        writer.WriteStringValue(UtcFormat.Write(value.UtcDateTime));
}

/// <summary><see cref="DateTime"/> alanları için UTC ISO 8601 dönüştürücüsü.</summary>
public sealed class UtcDateTimeConverter : JsonConverter<DateTime>
{
    public override DateTime Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) =>
        UtcFormat.Read(ref reader).UtcDateTime;

    // Veritabanında UTC saklanır; Kind belirtilmemişse UTC kabul edilir.
    public override void Write(Utf8JsonWriter writer, DateTime value, JsonSerializerOptions options) =>
        writer.WriteStringValue(UtcFormat.Write(value.Kind == DateTimeKind.Local ? value.ToUniversalTime() : value));
}
