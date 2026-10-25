using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Accounts;

namespace Yukum.Infrastructure.Identity;

/// <summary>
/// <see cref="ITokenService"/>'in JWT (HS256) ile gerçeği. Jeton yalnız <c>sub</c> (kullanıcı numarası), <c>role</c> ve
/// <c>jti</c> (jeton numarası) taşır; ad, e-posta, telefon gibi kişisel veri jetona yazılmaz çünkü jeton şifreli değil,
/// yalnız imzalıdır (içeriği herkes okuyabilir).
/// </summary>
public sealed class JwtTokenService(IOptions<JwtOptions> options, TimeProvider time) : ITokenService
{
    /// <inheritdoc />
    public AccessToken CreateAccessToken(AuthUserDto user)
    {
        // Jwt ayarları (JwtOptions): yayıncı, hedef, anahtar, ömür.
        var settings = options.Value;
        // Şimdi (UTC); testte sahte saatle denenebilir.
        var now = time.GetUtcNow().UtcDateTime;
        // Bitiş: şimdi + 15 dakika.
        var expires = now.AddMinutes(settings.AccessTokenMinutes);

        // Jetonun içeriği ve imza bilgisi bu nesnede tarif edilir.
        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = settings.Issuer,
            Audience = settings.Audience,
            // iat: jetonun üretildiği an.
            IssuedAt = now,
            // nbf: bu andan ÖNCE geçersiz.
            NotBefore = now,
            // exp: bu andan SONRA geçersiz.
            Expires = expires,
            Claims = new Dictionary<string, object>
            {
                // sub: kullanıcı numarası (jetonun sahibi). Başka kişisel veri yazılmaz.
                ["sub"] = user.Id.ToString(),
                // role: Shipper / Carrier / Admin. [Authorize(Roles = ...)] buna bakar.
                ["role"] = user.Role,
                // jti: bu jetona özel benzersiz numara (ileride tek tek izleme/iptal için).
                ["jti"] = Guid.NewGuid().ToString()
            },
            // İmza: gizli anahtar + HS256. Anahtarı bilmeyen biri imzayı taklit edemez; jetonun içeriği değişirse imza bozulur.
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings.SigningKey)), SecurityAlgorithms.HmacSha256)
        };

        // Jeton metnini üret (xxxxx.yyyyy.zzzzz biçimi) ve bitiş zamanıyla birlikte döndür.
        return new AccessToken(new JsonWebTokenHandler().CreateToken(descriptor), expires);
    }
}
