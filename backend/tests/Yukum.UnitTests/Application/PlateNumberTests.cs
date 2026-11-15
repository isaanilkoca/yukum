using Yukum.Application.Vehicles;

namespace Yukum.UnitTests.Application;

// Araçlarım (15 Kasım): plaka tek biçime çevrilir ve Türkiye biçimi denetlenir (il kodu 01-81, 1-3 harf, 2-5 rakam).
public class PlateNumberTests
{
    [Theory]
    [InlineData("34abc123", "34 ABC 123")]
    [InlineData(" 06 a 1234 ", "06 A 1234")]
    [InlineData("33-AB-12", "33 AB 12")]
    [InlineData("81 xyz 99999", "81 XYZ 99999")]
    [InlineData("35 iz 123", "35 IZ 123")] // Türkçe klavyeden gelen küçük i → I
    public void Valid_plates_are_normalized(string input, string expected) => Assert.Equal(expected, PlateNumber.Normalize(input));

    [Theory]
    [InlineData("")]
    [InlineData("82 ABC 123")]   // il kodu 81'den büyük
    [InlineData("00 ABC 123")]   // il kodu 00
    [InlineData("34 ABCD 12")]   // 4 harf
    [InlineData("34 ABC 1")]     // tek rakam
    [InlineData("ABC 123")]      // il kodu yok
    public void Invalid_plates_are_rejected(string input) => Assert.Null(PlateNumber.Normalize(input));
}
