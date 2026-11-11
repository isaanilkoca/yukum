using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Time.Testing;
using Yukum.Infrastructure.Push;

namespace Yukum.IntegrationTests.Auth;

// APNs kimlik jetonu (JWT, ES256): doğru başlık/gövde, .p8'deki anahtarla doğrulanabilen imza, 50 dakika önbellek.
// Gerçek Apple anahtarı kullanılmaz: test kendi P-256 anahtarını üretip geçici dosyaya yazar.
public class ApnsJwtFactoryTests : IDisposable
{
    private readonly string _keyPath = Path.Combine(Path.GetTempPath(), $"apns-test-{Guid.NewGuid():N}.p8");
    private readonly ECDsa _key = ECDsa.Create(ECCurve.NamedCurves.nistP256);
    private readonly FakeTimeProvider _time = new(new DateTimeOffset(2026, 11, 12, 9, 0, 0, TimeSpan.Zero));

    public ApnsJwtFactoryTests() => File.WriteAllText(_keyPath, _key.ExportPkcs8PrivateKeyPem());

    public void Dispose()
    {
        _key.Dispose();
        File.Delete(_keyPath);
    }

    private ApnsJwtFactory Factory() =>
        new(Options.Create(new ApnsOptions { Enabled = true, KeyPath = _keyPath, KeyId = "KEY1234567", TeamId = "TEAM123456", BundleId = "x.y" }), _time);

    private static byte[] Decode(string part) =>
        Convert.FromBase64String(part.Replace('-', '+').Replace('_', '/').PadRight(part.Length + (4 - part.Length % 4) % 4, '='));

    [Fact]
    public void Token_carries_key_id_team_id_and_a_signature_the_key_verifies()
    {
        var parts = Factory().GetToken().Split('.');

        Assert.Equal(3, parts.Length);
        var header = JsonDocument.Parse(Decode(parts[0])).RootElement;
        var payload = JsonDocument.Parse(Decode(parts[1])).RootElement;
        Assert.Equal("ES256", header.GetProperty("alg").GetString());
        Assert.Equal("KEY1234567", header.GetProperty("kid").GetString());
        Assert.Equal("TEAM123456", payload.GetProperty("iss").GetString());
        Assert.Equal(_time.GetUtcNow().ToUnixTimeSeconds(), payload.GetProperty("iat").GetInt64());
        Assert.True(_key.VerifyData(Encoding.ASCII.GetBytes($"{parts[0]}.{parts[1]}"), Decode(parts[2]), HashAlgorithmName.SHA256,
            DSASignatureFormat.IeeeP1363FixedFieldConcatenation));
    }

    [Fact]
    public void Token_is_reused_for_fifty_minutes_then_renewed()
    {
        var factory = Factory();
        var first = factory.GetToken();

        _time.Advance(TimeSpan.FromMinutes(49));
        var stillFirst = factory.GetToken();
        _time.Advance(TimeSpan.FromMinutes(2));
        var renewed = factory.GetToken();

        Assert.Equal(first, stillFirst);     // Apple: aynı jeton en az 20 dk kullanılmalı (her istekte yenisi = TooManyProviderTokenUpdates)
        Assert.NotEqual(first, renewed);     // Apple: 60 dk'dan eski jeton reddedilir (ExpiredProviderToken)
    }
}
