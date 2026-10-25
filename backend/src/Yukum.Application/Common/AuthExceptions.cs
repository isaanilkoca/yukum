namespace Yukum.Application.Common;

/// <summary>
/// E-posta/telefon ya da şifre hatalı. Mesaj bilerek **tek ve genel**dir: kullanıcının hiç var olmaması ile şifrenin
/// yanlış olması aynı cevabı verir, böylece saldırgan "bu e-posta kayıtlı mı?" diye yoklayamaz (rapor 6.2). API'de 401.
/// </summary>
public sealed class InvalidCredentialsException() : Exception("E-posta veya şifre hatalı.");

/// <summary>
/// Çok sayıda hatalı denemeden sonra hesap geçici olarak kilitlendi (rapor 6.2: 5 hatada kilit). API'de 423 ve
/// <c>Retry-After</c> başlığı.
/// </summary>
/// <param name="retryAfter">Kilidin açılmasına kalan süre.</param>
public sealed class AccountLockedException(TimeSpan retryAfter)
    : Exception("Çok fazla hatalı deneme yapıldı. Hesabınız geçici olarak kilitlendi, lütfen daha sonra tekrar deneyin.")
{
    /// <summary>Kilidin açılmasına kalan süre.</summary>
    public TimeSpan RetryAfter { get; } = retryAfter;
}

/// <summary>
/// Kimliği doğrulanmış kullanıcı bu işlemi yapamaz (örn. hesabı devre dışı bırakılmış). API'de 403.
/// Mesaj istemciye olduğu gibi gösterilir, iç ayrıntı içermemelidir.
/// </summary>
/// <param name="message">Kullanıcıya gösterilebilecek kısa Türkçe açıklama.</param>
public sealed class ForbiddenException(string message) : Exception(message);
