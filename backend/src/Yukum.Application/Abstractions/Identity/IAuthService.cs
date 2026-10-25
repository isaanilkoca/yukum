using Yukum.Application.Accounts;

namespace Yukum.Application.Abstractions.Identity;

/// <summary>
/// Giriş bilgilerini (e-posta/telefon + şifre) doğrulama sözleşmesi. Gerçeği Infrastructure'dadır (ASP.NET Core Identity);
/// iş kuralı kodu Identity'yi bilmez.
/// </summary>
public interface IAuthService
{
    /// <summary>
    /// Şifreyi doğrular, hatalı denemeleri sayar (5 hatada kilit) ve başarılıysa kullanıcı özetini döndürür.
    /// Verilen kimliklerden yalnız biri dolu olur: e-posta ya da telefon (normalleştirilmiş).
    /// </summary>
    /// <param name="email">Küçük harfe çevrilmiş e-posta; telefonla girişte <c>null</c>.</param>
    /// <param name="phone"><c>+905XXXXXXXXX</c> biçiminde telefon; e-postayla girişte <c>null</c>.</param>
    /// <param name="password">Girilen şifre.</param>
    /// <param name="cancellationToken">İşlemi yarıda kesmek için.</param>
    /// <exception cref="Common.InvalidCredentialsException">Kullanıcı yok ya da şifre yanlış (ayırt edilemez).</exception>
    /// <exception cref="Common.AccountLockedException">Hesap geçici olarak kilitli.</exception>
    /// <exception cref="Common.ForbiddenException">Şifre doğru ama hesap devre dışı ya da engelli.</exception>
    Task<AuthUserDto> VerifyCredentialsAsync(string? email, string? phone, string password, CancellationToken cancellationToken = default);
}
