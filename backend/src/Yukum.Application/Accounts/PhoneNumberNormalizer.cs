using System.Text;

namespace Yukum.Application.Accounts;

/// <summary>
/// Türkiye cep telefonu numarasını tek biçime (<c>+905321234567</c>) çevirir. Kullanıcı numarayı "0532 123 45 67",
/// "532-123-4567", "+90 (532) 123 45 67" gibi farklı yazabilir; hepsi aynı numara sayılmalı, yoksa aynı telefonla
/// iki hesap açılabilir.
/// </summary>
public static class PhoneNumberNormalizer
{
    /// <summary>Numarayı normalleştirir; cep telefonu değilse <c>false</c> döner.</summary>
    /// <param name="input">Kullanıcının yazdığı metin.</param>
    /// <param name="normalized">Başarılıysa <c>+905XXXXXXXXX</c>, değilse boş metin.</param>
    public static bool TryNormalize(string? input, out string normalized)
    {
        normalized = "";
        if (string.IsNullOrWhiteSpace(input))
            return false;

        // Yalnız rakamlar toplanır; boşluk, tire, nokta ve parantez yok sayılır, başka karakter varsa numara geçersizdir.
        // "+" yalnız en başta, bir kez kabul edilir.
        var digits = new StringBuilder();
        var hasPlus = false;
        foreach (var ch in input.Trim())
        {
            if (char.IsAsciiDigit(ch))
                digits.Append(ch);
            else if (ch == '+' && digits.Length == 0 && !hasPlus)
                hasPlus = true;
            else if (ch is not (' ' or '-' or '.' or '(' or ')'))
                return false;
        }

        var number = digits.ToString();

        // Ülke kodunu (90) ya da baştaki 0'ı atıp 10 haneli ulusal numaraya ulaşırız.
        string national;
        if (hasPlus)
            national = number.StartsWith("90", StringComparison.Ordinal) ? number[2..] : "";
        else if (number.StartsWith("0090", StringComparison.Ordinal))
            national = number[4..];
        else if (number.Length == 12 && number.StartsWith("90", StringComparison.Ordinal))
            national = number[2..];
        else if (number.Length == 11 && number.StartsWith('0'))
            national = number[1..];
        else
            national = number;

        // Cep telefonları 5 ile başlar (5XX XXX XX XX).
        if (national.Length != 10 || national[0] != '5')
            return false;

        normalized = "+90" + national;
        return true;
    }
}
