using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;

namespace Yukum.Application.PriceReference;

/// <summary>Bir rota için emsal fiyat (medyan) hesaplar. Yeterli veri yoksa fiyat dönmez.</summary>
public sealed class GetPriceReferenceHandler(IPriceReferenceRepository repository, TimeProvider time)
    : IQueryHandler<GetPriceReferenceQuery, PriceReferenceDto>
{
    // FONKSİYON ROLÜ: API'NİN İŞ MANTIĞI | PriceReferenceController çağırır: son 180 günün tamamlanmış iş tutarlarını okur, medyanı alır
    /// <summary>Örnek sayısı <see cref="PriceMedian.MinSamples"/>'den azsa <c>MedianAmount</c> null döner (200 OK).</summary>
    public async Task<PriceReferenceDto> HandleAsync(GetPriceReferenceQuery query, CancellationToken cancellationToken = default)
    {
        var since = time.GetUtcNow().UtcDateTime.AddDays(-PriceMedian.WindowDays);
        var amounts = await repository.ListCompletedAmountsAsync(
            query.FromCityId, query.ToCityId, query.VehicleType, since, PriceMedian.MaxSamples, cancellationToken);
        return new PriceReferenceDto(PriceMedian.Compute(amounts), amounts.Count);
    }
}
