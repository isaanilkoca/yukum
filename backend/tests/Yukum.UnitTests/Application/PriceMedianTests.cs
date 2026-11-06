using Yukum.Application.PriceReference;

namespace Yukum.UnitTests.Application;

/// <summary>Medyan hesabı: saf fonksiyon, veritabanı gerekmez.</summary>
public class PriceMedianTests
{
    [Fact]
    public void Fewer_than_three_samples_give_no_price()
    {
        Assert.Null(PriceMedian.Compute([]));
        Assert.Null(PriceMedian.Compute([1000m, 2000m])); // 2 örnek: yanıltıcı olur
    }

    [Fact]
    public void An_odd_count_takes_the_middle_value_regardless_of_input_order()
    {
        Assert.Equal(2000m, PriceMedian.Compute([4000m, 1000m, 2000m]));
    }

    [Fact]
    public void An_even_count_averages_the_two_middle_values()
    {
        Assert.Equal(2500m, PriceMedian.Compute([1000m, 2000m, 3000m, 9000m]));
    }

    [Fact]
    public void One_extreme_value_does_not_move_the_median()
    {
        // Ortalama bu listede 200.600 TL olurdu; medyan 2000 TL kalır. Medyanı seçme sebebi bu.
        Assert.Equal(2000m, PriceMedian.Compute([1m, 1000m, 2000m, 3000m, 1_000_000m]));
    }
}
