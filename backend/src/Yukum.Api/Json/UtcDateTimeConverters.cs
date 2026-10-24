using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Yukum.Api.Json;

// Tarih sözleşmesi: yazarken daima UTC "2026-10-20T10:15:00Z" (kesirli saniye YOK; Swift .iso8601 kesirli saniyeyi okuyamaz).
// Okurken ofsetli her ISO 8601 girdisi kabul edilir ve UTC'ye çevrilir; ofseti olmayan girdi UTC sayılır.
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

public sealed class UtcDateTimeOffsetConverter : JsonConverter<DateTimeOffset>
{
    public override DateTimeOffset Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) =>
        UtcFormat.Read(ref reader);

    public override void Write(Utf8JsonWriter writer, DateTimeOffset value, JsonSerializerOptions options) =>
        writer.WriteStringValue(UtcFormat.Write(value.UtcDateTime));
}

public sealed class UtcDateTimeConverter : JsonConverter<DateTime>
{
    public override DateTime Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) =>
        UtcFormat.Read(ref reader).UtcDateTime;

    // Veritabanında UTC saklanır; Kind belirtilmemişse UTC kabul edilir.
    public override void Write(Utf8JsonWriter writer, DateTime value, JsonSerializerOptions options) =>
        writer.WriteStringValue(UtcFormat.Write(value.Kind == DateTimeKind.Local ? value.ToUniversalTime() : value));
}
