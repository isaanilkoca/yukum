namespace Yukum.Application.Accounts;

/// <summary>
/// Şifre kuralları (karar K-017): en az 8, en fazla 128 karakter; en az bir büyük harf, bir küçük harf, bir rakam.
/// Kural tek yerde durur: hem kayıt doğrulaması (Türkçe mesajlarla) hem Identity (ikinci savunma) buradan okur,
/// böylece ikisi birbirinden ayrışamaz. Harf kontrolü Unicode'dur: "Şifre1234" büyük harf (Ş) içerir.
/// </summary>
public static class PasswordPolicy
{
    /// <summary>En az karakter sayısı.</summary>
    public const int MinLength = 8;

    /// <summary>En çok karakter sayısı (aşırı uzun şifreyle hash'leme maliyetini şişirmeyi önler).</summary>
    public const int MaxLength = 128;

    /// <summary>En az bir büyük harf var mı?</summary>
    public static bool HasUppercase(string password) => password.Any(char.IsUpper);

    /// <summary>En az bir küçük harf var mı?</summary>
    public static bool HasLowercase(string password) => password.Any(char.IsLower);

    /// <summary>En az bir rakam (0–9) var mı?</summary>
    public static bool HasDigit(string password) => password.Any(char.IsAsciiDigit);

    /// <summary>Şifre kuralların hepsine uyuyor mu?</summary>
    public static bool IsValid(string password) =>
        password.Length is >= MinLength and <= MaxLength && HasUppercase(password) && HasLowercase(password) && HasDigit(password);
}
