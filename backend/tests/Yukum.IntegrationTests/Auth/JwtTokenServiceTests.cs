using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Time.Testing;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Accounts;
using Yukum.Infrastructure;
using Yukum.Infrastructure.Identity;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Auth;

// Erişim jetonu (JWT): içeriği, imzası, ömrü ve ayarların doğrulanması. Veritabanı gerekmez.
public class JwtTokenServiceTests
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 25, 9, 0, 0, TimeSpan.Zero);
    private static readonly AuthUserDto User = new(Guid.Parse("11111111-2222-3333-4444-555555555555"), "Ali Veli", "Shipper", "https://x/a.png");

    private static JwtTokenService NewService(int minutes = 15, string key = TestJwt.Key) =>
        new(Options.Create(new JwtOptions { Issuer = TestJwt.Issuer, Audience = TestJwt.Audience, SigningKey = key, AccessTokenMinutes = minutes }),
            new FakeTimeProvider(T0));

    private static async Task<TokenValidationResult> ValidateAsync(string token, string key = TestJwt.Key) =>
        await new JsonWebTokenHandler().ValidateTokenAsync(token, new TokenValidationParameters
        {
            ValidIssuer = TestJwt.Issuer,
            ValidAudience = TestJwt.Audience,
            IssuerSigningKey = TestJwt.SecurityKey(key),
            ValidateLifetime = false
        });

    [Fact]
    public async Task Token_carries_sub_role_and_jti_and_the_expected_issuer_audience_and_lifetime()
    {
        var token = NewService().CreateAccessToken(User);

        var result = await ValidateAsync(token.Value);

        Assert.True(result.IsValid);
        var jwt = (JsonWebToken)result.SecurityToken;
        Assert.Equal("11111111-2222-3333-4444-555555555555", jwt.GetClaim("sub").Value);
        Assert.Equal("Shipper", jwt.GetClaim("role").Value);
        Assert.True(Guid.TryParse(jwt.GetClaim("jti").Value, out _));
        Assert.Equal(TestJwt.Issuer, jwt.Issuer);
        Assert.Contains(TestJwt.Audience, jwt.Audiences);
        Assert.Equal(T0.AddMinutes(15).UtcDateTime, jwt.ValidTo);
        Assert.Equal(T0.UtcDateTime, jwt.ValidFrom);
        Assert.Equal("HS256", jwt.Alg);
    }

    [Fact]
    public async Task Token_contains_no_personal_data()
    {
        var jwt = (JsonWebToken)(await ValidateAsync(NewService().CreateAccessToken(User).Value)).SecurityToken;

        var types = jwt.Claims.Select(c => c.Type).ToHashSet();

        Assert.Subset(new HashSet<string> { "sub", "role", "jti", "iss", "aud", "exp", "iat", "nbf" }, types);
        Assert.DoesNotContain("Ali Veli", jwt.EncodedPayload);   // yük base64'tür; ad geçiyorsa claim olarak çözülmüş olurdu
        Assert.DoesNotContain(jwt.Claims, c => c.Value.Contains("Ali") || c.Value.Contains("a.png"));
    }

    [Fact]
    public void ExpiresAt_matches_the_token_and_is_utc()
    {
        var token = NewService(minutes: 10).CreateAccessToken(User);

        Assert.Equal(T0.AddMinutes(10).UtcDateTime, token.ExpiresAt);
        Assert.Equal(DateTimeKind.Utc, token.ExpiresAt.Kind);
    }

    [Fact]
    public void Every_token_has_its_own_jti()
    {
        var service = NewService();

        var first = new JsonWebToken(service.CreateAccessToken(User).Value).GetClaim("jti").Value;
        var second = new JsonWebToken(service.CreateAccessToken(User).Value).GetClaim("jti").Value;

        Assert.NotEqual(first, second);
    }

    [Fact]
    public async Task A_token_signed_with_another_key_or_tampered_with_is_rejected()
    {
        var token = NewService().CreateAccessToken(User).Value;

        Assert.False((await ValidateAsync(token, key: "baska-bir-imza-anahtari-en-az-32-karakter-uzunlugunda!")).IsValid);

        var parts = token.Split('.');
        var tampered = $"{parts[0]}.{parts[1][..^2]}AA.{parts[2]}";
        Assert.False((await ValidateAsync(tampered)).IsValid);
    }

    // ---------- ayar doğrulaması ----------
    private static IOptions<JwtOptions> OptionsFrom(Dictionary<string, string?> values)
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(values).Build();
        var services = new ServiceCollection();
        services.AddSingleton<IConfiguration>(configuration);
        services.AddAccounts();
        return services.BuildServiceProvider().GetRequiredService<IOptions<JwtOptions>>();
    }

    private static Dictionary<string, string?> Good() => new()
    {
        ["Jwt:Issuer"] = "i", ["Jwt:Audience"] = "a", ["Jwt:SigningKey"] = TestJwt.Key, ["Jwt:AccessTokenMinutes"] = "15"
    };

    [Fact]
    public void A_complete_configuration_is_accepted()
    {
        var jwt = OptionsFrom(Good()).Value;

        Assert.Equal("i", jwt.Issuer);
        Assert.Equal(15, jwt.AccessTokenMinutes);
    }

    [Fact]
    public void A_missing_or_short_signing_key_is_refused()
    {
        var missing = Good();
        missing.Remove("Jwt:SigningKey");
        var short1 = Good();
        short1["Jwt:SigningKey"] = "kisa-anahtar";

        Assert.Throws<OptionsValidationException>(() => OptionsFrom(missing).Value);
        Assert.Throws<OptionsValidationException>(() => OptionsFrom(short1).Value);
    }

    [Theory]
    [InlineData("Jwt:Issuer")]
    [InlineData("Jwt:Audience")]
    public void A_missing_issuer_or_audience_is_refused(string key)
    {
        var values = Good();
        values[key] = "";

        Assert.Throws<OptionsValidationException>(() => OptionsFrom(values).Value);
    }

    [Theory]
    [InlineData("4")]
    [InlineData("61")]
    [InlineData("0")]
    public void A_lifetime_outside_5_to_60_minutes_is_refused(string minutes)
    {
        var values = Good();
        values["Jwt:AccessTokenMinutes"] = minutes;

        Assert.Throws<OptionsValidationException>(() => OptionsFrom(values).Value);
    }
}
