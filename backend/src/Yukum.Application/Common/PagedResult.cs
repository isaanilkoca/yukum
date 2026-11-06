namespace Yukum.Application.Common;

/// <summary>Sayfalı cevap zarfı (sözleşme: <c>{ items, page, pageSize, totalCount }</c>). İstemci "başka sayfa var mı" kararını totalCount'tan verir.</summary>
/// <param name="Items">Bu sayfadaki kayıtlar.</param>
/// <param name="Page">Sayfa numarası (1'den başlar).</param>
/// <param name="PageSize">Sayfa başına en çok kaç kayıt istendi.</param>
/// <param name="TotalCount">Filtreye uyan TÜM kayıtların sayısı (yalnız bu sayfadakiler değil).</param>
public sealed record PagedResult<T>(IReadOnlyList<T> Items, int Page, int PageSize, int TotalCount);
