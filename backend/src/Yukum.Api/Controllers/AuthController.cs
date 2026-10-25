using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Accounts;

namespace Yukum.Api.Controllers;

/// <summary>
/// Kayıt ve giriş uçları. Hepsi anonimdir: kullanıcı henüz giriş yapmamıştır.
/// İki kullanıcı türü için iki ayrı kayıt ucu vardır; rolü endpoint'in kendisi belirler, istemciden rol alanı gelmez.
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/auth")]
[AllowAnonymous]
public class AuthController(
    ICommandHandler<RegisterShipperCommand, RegisteredUserDto> registerShipper,
    ICommandHandler<RegisterCarrierCommand, RegisteredUserDto> registerCarrier,
    ICommandHandler<LoginCommand, LoginResponse> login) : ControllerBase
{
    /// <summary>E-posta ya da telefon + şifre ile giriş yapar ve kısa ömürlü erişim jetonu (JWT) verir.</summary>
    /// <param name="command">Giriş bilgileri (cihaz kimliği zorunludur).</param>
    /// <param name="cancellationToken">İstemci isteği iptal ederse işlem de durur.</param>
    /// <returns>
    /// 200: jeton, bitiş zamanı ve kullanıcı özeti. Alan eksik: 400. Kullanıcı/şifre hatalı: 401 (hangisi olduğu söylenmez).
    /// Hesap devre dışı: 403. 5 hatalı denemeden sonra geçici kilit: 423 ve <c>Retry-After</c> başlığı.
    /// </returns>
    [HttpPost("login")]
    [ProducesResponseType<LoginResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status423Locked)]
    public async Task<IActionResult> Login(LoginCommand command, CancellationToken cancellationToken) =>
        Ok(await login.HandleAsync(command, cancellationToken));

    /// <summary>Yük Veren olarak kayıt olur. Rol: Shipper.</summary>
    /// <param name="command">Kayıt bilgileri.</param>
    /// <param name="cancellationToken">İstemci isteği iptal ederse işlem de durur.</param>
    /// <returns>201 ve kullanıcı özeti. Geçersiz alan: 400. E-posta/telefon kayıtlı: 409. Giriş ayrı uçtan yapılır.</returns>
    [HttpPost("register/shipper")]
    [ProducesResponseType<RegisteredUserDto>(StatusCodes.Status201Created)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> RegisterShipper(RegisterShipperCommand command, CancellationToken cancellationToken) =>
        StatusCode(StatusCodes.Status201Created, await registerShipper.HandleAsync(command, cancellationToken));

    /// <summary>Taşımacı olarak kayıt olur (en az 1 araçla). Rol: Carrier.</summary>
    /// <param name="command">Kayıt bilgileri.</param>
    /// <param name="cancellationToken">İstemci isteği iptal ederse işlem de durur.</param>
    /// <returns>201 ve kullanıcı özeti. Geçersiz alan: 400. E-posta/telefon kayıtlı: 409. Giriş ayrı uçtan yapılır.</returns>
    [HttpPost("register/carrier")]
    [ProducesResponseType<RegisteredUserDto>(StatusCodes.Status201Created)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> RegisterCarrier(RegisterCarrierCommand command, CancellationToken cancellationToken) =>
        StatusCode(StatusCodes.Status201Created, await registerCarrier.HandleAsync(command, cancellationToken));
}
