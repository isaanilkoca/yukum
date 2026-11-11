using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace Yukum.Infrastructure.Push;

/// <summary>
/// APNs'e kimliğimizi kanıtlayan kısa ömürlü jetonu (JWT, ES256) üretir: başlıkta Key ID, gövdede Team ID + üretim anı, .p8'deki özel anahtarla imzalı.
/// Apple aynı jetonun 20–60 dakika kullanılmasını ister (her istekte yenisi üretilirse reddeder): jeton 50 dakika önbellekte tutulur.
/// </summary>
public sealed class ApnsJwtFactory(IOptions<ApnsOptions> options, TimeProvider time)
{
    private static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(50);
    private readonly Lock _gate = new();
    private string? _token;
    private DateTimeOffset _createdAt;

    /// <summary>Geçerli jetonu döner; yoksa ya da süresi dolduysa yenisini üretir.</summary>
    public string GetToken()
    {
        lock (_gate)
        {
            var now = time.GetUtcNow();
            if (_token is not null && now - _createdAt < Lifetime) return _token;
            _token = Create(options.Value, now);
            _createdAt = now;
            return _token;
        }
    }

    // JWT = base64url(başlık) . base64url(gövde) . base64url(imza). Apple yalnız iss + iat ister.
    private static string Create(ApnsOptions o, DateTimeOffset now)
    {
        var header = Encode(JsonSerializer.SerializeToUtf8Bytes(new { alg = "ES256", kid = o.KeyId }));
        var payload = Encode(JsonSerializer.SerializeToUtf8Bytes(new { iss = o.TeamId, iat = now.ToUnixTimeSeconds() }));
        using var key = ECDsa.Create();
        key.ImportFromPem(File.ReadAllText(o.KeyPath));   // .p8 = PEM biçiminde P-256 özel anahtar
        var signature = key.SignData(Encoding.ASCII.GetBytes($"{header}.{payload}"), HashAlgorithmName.SHA256,
            DSASignatureFormat.IeeeP1363FixedFieldConcatenation);   // JWT'nin istediği düz r||s biçimi (DER değil)
        return $"{header}.{payload}.{Encode(signature)}";
    }

    private static string Encode(byte[] bytes) => Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}
