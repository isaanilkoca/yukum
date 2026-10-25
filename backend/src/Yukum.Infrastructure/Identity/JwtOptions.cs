namespace Yukum.Infrastructure.Identity;

/// <summary>
/// Erişim jetonu (JWT) ayarları; <c>appsettings.json</c>'daki "Jwt" bölümünden okunur.
/// <see cref="SigningKey"/> gizlidir: repoya yazılmaz, geliştirmede user-secrets'ta, canlıda ortam değişkeninde durur.
/// </summary>
public sealed class JwtOptions
{
    /// <summary>Jetonu kimin ürettiğini belirten ad.</summary>
    public string Issuer { get; set; } = "";

    /// <summary>Jetonun kimin için üretildiğini belirten ad.</summary>
    public string Audience { get; set; } = "";

    /// <summary>İmza anahtarı (HS256). En az 32 karakter (256 bit) olmalıdır. Bu anahtarı bilen herkes sahte jeton üretebilir.</summary>
    public string SigningKey { get; set; } = "";

    /// <summary>Erişim jetonunun ömrü, dakika (rapor: 10–15).</summary>
    public int AccessTokenMinutes { get; set; } = 15;
}
