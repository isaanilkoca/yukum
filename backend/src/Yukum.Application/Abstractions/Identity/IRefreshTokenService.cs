using Yukum.Application.Accounts;

namespace Yukum.Application.Abstractions.Identity;

/// <summary>
/// Yenileme jetonu (refresh token) yönetimi. Jeton rastgele üretilir, DB'ye yalnız SHA-256 özeti yazılır (düz hâli saklanmaz).
/// Her kullanımda yenisi verilip eskisi iptal edilir (rotasyon). İptal edilmiş jeton tekrar gelirse çalıntı sayılır ve
/// o cihazın tüm jetonları iptal edilir.
/// </summary>
public interface IRefreshTokenService
{
    /// <summary>Girişte yeni jeton verir; aynı kullanıcı + cihazın önceki jetonlarını iptal eder (cihaz başına tek oturum).</summary>
    Task<RefreshTokenIssue> IssueAsync(Guid userId, string deviceId, CancellationToken cancellationToken = default);

    /// <summary>Jetonu doğrular, eskisini iptal edip yenisini verir. Geçersizse <c>InvalidRefreshTokenException</c> (401).</summary>
    Task<RefreshTokenRotation> RotateAsync(string rawToken, string deviceId, CancellationToken cancellationToken = default);

    /// <summary>Çıkış: jetonun cihazındaki tüm aktif jetonları iptal eder. Jeton bilinmiyorsa sessizce geçer (çıkış her zaman başarılı sayılır).</summary>
    Task RevokeAsync(string rawToken, CancellationToken cancellationToken = default);
}

/// <summary>Verilen jeton: düz hâli YALNIZ bu cevapta bir kez döner (DB'de yalnız özeti vardır).</summary>
public sealed record RefreshTokenIssue(string Token, DateTime ExpiresAt);

/// <summary>Rotasyon sonucu: jetonun sahibi (yeni erişim jetonu için) ve yeni yenileme jetonu.</summary>
public sealed record RefreshTokenRotation(AuthUserDto User, RefreshTokenIssue Token);
