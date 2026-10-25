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
        var settings = options.Value;
        var now = time.GetUtcNow().UtcDateTime;
        var expires = now.AddMinutes(settings.AccessTokenMinutes);

        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = settings.Issuer,
            Audience = settings.Audience,
            IssuedAt = now,
            NotBefore = now,
            Expires = expires,
            Claims = new Dictionary<string, object>
            {
                ["sub"] = user.Id.ToString(),
                ["role"] = user.Role,
                ["jti"] = Guid.NewGuid().ToString()
            },
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings.SigningKey)), SecurityAlgorithms.HmacSha256)
        };

        return new AccessToken(new JsonWebTokenHandler().CreateToken(descriptor), expires);
    }
}
