using Yukum.Domain.Accounts;

namespace Yukum.Application.PriceReference;

/// <summary>Sorgu: aynı kalkış ili, varış ili ve araç tipi için emsal fiyat.</summary>
public sealed record GetPriceReferenceQuery(int FromCityId, int ToCityId, VehicleType VehicleType);

/// <summary>Emsal fiyat cevabı: son tamamlanan işlerin medyan tutarı; yeterli iş yoksa <c>MedianAmount</c> boştur (null) ve gösterilmez.</summary>
public sealed record PriceReferenceDto(decimal? MedianAmount, int SampleCount);
