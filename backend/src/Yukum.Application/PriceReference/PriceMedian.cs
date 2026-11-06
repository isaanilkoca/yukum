namespace Yukum.Application.PriceReference;

/// <summary>Medyan hesabı ve emsal fiyat sabitleri. Saf fonksiyon: veritabanına dokunmaz, tek başına test edilir.</summary>
public static class PriceMedian
{
    /// <summary>Emsal gösterilmesi için gereken en az tamamlanmış iş sayısı (azsa tek bir uç fiyat yanıltır).</summary>
    public const int MinSamples = 3;

    /// <summary>Geriye bakılan gün sayısı (eski fiyatlar güncel piyasayı yansıtmaz).</summary>
    public const int WindowDays = 180;

    /// <summary>En çok kaç iş örneklenir (en yeniler); hesap hafif kalır.</summary>
    public const int MaxSamples = 200;

    /// <summary>
    /// Medyan = sıralı listenin ortadaki değeri (çift sayıda ise ortadaki ikisinin ortalaması).
    /// NEDEN ortalama değil medyan: tek bir uç değer (örn. 1 TL ya da 1.000.000 TL) ortalamayı bozar, medyanı bozmaz.
    /// </summary>
    public static decimal? Compute(IReadOnlyList<decimal> amounts)
    {
        if (amounts.Count < MinSamples) return null;
        var sorted = amounts.OrderBy(a => a).ToList();
        var mid = sorted.Count / 2;
        var median = sorted.Count % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2m;
        return Math.Round(median, 2);
    }
}
