using Yukum.Application.Accounts;

namespace Yukum.Application.Abstractions.Identity;

/// <summary>Kısa ömürlü erişim jetonu (JWT) üretme sözleşmesi. Gerçeği Infrastructure'dadır.</summary>
public interface ITokenService
{
    /// <summary>
    /// Kullanıcı için imzalı erişim jetonu üretir. İçinde yalnız kullanıcı numarası (<c>sub</c>), rol (<c>role</c>) ve
    /// jeton numarası (<c>jti</c>) bulunur; e-posta, ad gibi kişisel veri jetona yazılmaz.
    /// </summary>
    /// <param name="user">Jetonun sahibi.</param>
    AccessToken CreateAccessToken(AuthUserDto user);
}

/// <summary>Üretilen erişim jetonu ve bitiş zamanı.</summary>
/// <param name="Value">Jetonun kendisi (<c>Authorization: Bearer …</c> başlığında gönderilir).</param>
/// <param name="ExpiresAt">Bitiş zamanı (UTC).</param>
public sealed record AccessToken(string Value, DateTime ExpiresAt);
