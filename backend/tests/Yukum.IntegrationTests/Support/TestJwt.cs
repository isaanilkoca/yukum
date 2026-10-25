using System.Text;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace Yukum.IntegrationTests.Support;

// YALNIZ TEST: sahte ama geçerli biçimde bir JWT ayarı ve yardımcı jeton üretici (süresi dolmuş/yanlış imzalı jetonlar için).
public static class TestJwt
{
    public const string Issuer = "yukum-test";
    public const string Audience = "yukum-test-client";
    public const string Key = "test-imza-anahtari-en-az-32-karakter-uzunlugunda-0123456789";

    public static SymmetricSecurityKey SecurityKey(string key = Key) => new(Encoding.UTF8.GetBytes(key));

    // Verilen koşullarla imzalı jeton üretir; testler bununla geçersiz jetonlar (süresi dolmuş, yanlış anahtar, yanlış hedef) hazırlar.
    public static string Create(
        Guid? userId = null, string role = "Shipper", string key = Key, string issuer = Issuer, string audience = Audience,
        DateTime? notBefore = null, DateTime? expires = null)
    {
        var now = DateTime.UtcNow;
        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = issuer,
            Audience = audience,
            NotBefore = notBefore ?? now.AddMinutes(-1),
            Expires = expires ?? now.AddMinutes(10),
            Claims = new Dictionary<string, object>
            {
                ["sub"] = (userId ?? Guid.NewGuid()).ToString(),
                ["role"] = role,
                ["jti"] = Guid.NewGuid().ToString()
            },
            SigningCredentials = new SigningCredentials(SecurityKey(key), SecurityAlgorithms.HmacSha256)
        };
        return new JsonWebTokenHandler().CreateToken(descriptor);
    }
}
