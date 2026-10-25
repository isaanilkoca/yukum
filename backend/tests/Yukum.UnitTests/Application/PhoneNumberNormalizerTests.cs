using Yukum.Application.Accounts;

namespace Yukum.UnitTests.Application;

// Telefon numarası tek biçime (+905XXXXXXXXX) çevrilir; aynı numara farklı yazılışla iki hesap açamasın.
public class PhoneNumberNormalizerTests
{
    [Theory]
    [InlineData("05321234567")]
    [InlineData("5321234567")]
    [InlineData("+905321234567")]
    [InlineData("905321234567")]
    [InlineData("00905321234567")]
    [InlineData("0532 123 45 67")]
    [InlineData("532-123-45-67")]
    [InlineData("+90 (532) 123 45 67")]
    [InlineData("  0532.123.45.67  ")]
    public void Valid_mobile_numbers_are_normalized_to_plus90_format(string input)
    {
        Assert.True(PhoneNumberNormalizer.TryNormalize(input, out var normalized));
        Assert.Equal("+905321234567", normalized);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("abc")]
    [InlineData("02121234567")]       // sabit hat, cep değil
    [InlineData("0532123456")]        // kısa
    [InlineData("053212345678")]      // uzun
    [InlineData("+14155552671")]      // yabancı numara
    [InlineData("4321234567")]        // 5 ile başlamıyor
    [InlineData("0532 123 45 6x")]    // harf içeriyor
    [InlineData("++905321234567")]
    public void Anything_else_is_rejected(string? input)
    {
        Assert.False(PhoneNumberNormalizer.TryNormalize(input, out var normalized));
        Assert.Equal("", normalized);
    }
}
