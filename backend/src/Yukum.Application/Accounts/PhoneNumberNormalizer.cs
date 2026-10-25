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
        // Başarısız olursa dışarıya boş metin dönsün.
        normalized = "";
        // Boş girdi geçersizdir.
        if (string.IsNullOrWhiteSpace(input))
            return false;

        // Yalnız rakamlar toplanır; boşluk, tire, nokta ve parantez yok sayılır, başka karakter varsa numara geçersizdir.
        // "+" yalnız en başta, bir kez kabul edilir.
        // Rakamlar burada biriktirilir.
        var digits = new StringBuilder();
        // Numara '+' ile başladı mı?
        var hasPlus = false;
        // Karakter karakter gez.
        foreach (var ch in input.Trim())
        {
            // Rakam (0-9): biriktir.
            if (char.IsAsciiDigit(ch))
                digits.Append(ch);
            // '+' yalnız en başta ve bir kez olabilir.
            else if (ch == '+' && digits.Length == 0 && !hasPlus)
                hasPlus = true;
            // Boşluk - . ( ) görmezden gelinir. Bunların dışındaki her karakter (harf vb.) numarayı geçersiz yapar.
            else if (ch is not (' ' or '-' or '.' or '(' or ')'))
                return false;
        }

        // Elimizde yalnız rakamlar var. Şimdi ülke kodu (90) ya da baştaki 0 atılıp 10 haneli ulusal numaraya ulaşılacak.
        var number = digits.ToString();

        // Ülke kodunu (90) ya da baştaki 0'ı atıp 10 haneli ulusal numaraya ulaşırız.
        string national;
        // +90 532... biçimi: 90'dan sonrası ulusal numara. '+' ile başlayıp 90'la başlamıyorsa yabancı numaradır → geçersiz.
        if (hasPlus)
            national = number.StartsWith("90", StringComparison.Ordinal) ? number[2..] : "";
        // 0090 532... biçimi.
        else if (number.StartsWith("0090", StringComparison.Ordinal))
            national = number[4..];
        // 90 532... (12 hane) biçimi.
        else if (number.Length == 12 && number.StartsWith("90", StringComparison.Ordinal))
            national = number[2..];
        // 0532... (11 hane) biçimi: baştaki 0 atılır.
        else if (number.Length == 11 && number.StartsWith('0'))
            national = number[1..];
        else
            // Diğer: zaten 532... (10 hane) biçiminde olabilir.
            national = number;

        // Cep telefonları 5 ile başlar (5XX XXX XX XX).
        if (national.Length != 10 || national[0] != '5')
            return false;

        // Tek biçim: +90 ile başlayan 13 karakter (uluslararası E.164). Veritabanı ve benzersizlik kontrolü hep bu biçimle çalışır.
        normalized = "+90" + national;
        return true;
    }
}
