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
// [ApiController]: bu sınıf bir API ucudur. İstek gövdesini (JSON) otomatik C# nesnesine çevirir, bozuksa otomatik 400 üretir.
[ApiController]
// Bu controller API sürüm 1.0'a aittir.
[ApiVersion("1.0")]
// Adres: /api/v1/auth/... ({version} yerine sürüm gelir).
[Route("api/v{version:apiVersion}/auth")]
// Giriş (jeton) gerekmez: kullanıcı henüz giriş yapmamıştır.
[AllowAnonymous]
// Bağımlılık enjeksiyonu: .NET, aşağıdaki üç handler'ı kendisi bulup verir (kayıtlar: Application/DependencyInjection.cs).
// Controller 'ince' tutulur: iş kuralı burada değil handler'lardadır.
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
    // POST /api/v1/auth/login
    [HttpPost("login")]
    // [ProducesResponseType]: Scalar/OpenAPI belgesine bu ucun verebileceği cevapları yazar; iOS sözleşmesinin kaynağı budur.
    [ProducesResponseType<LoginResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status423Locked)]
    // 'command' istek gövdesinden (JSON) gelir; CancellationToken: istemci bağlantıyı keserse işlem de durur.
    public async Task<IActionResult> Login(LoginCommand command, CancellationToken cancellationToken) =>
        // 200 OK + sonuç JSON olarak döner. Hata olursa handler istisna fırlatır; 401/423 gibi cevabı GlobalExceptionHandler üretir.
        Ok(await login.HandleAsync(command, cancellationToken));

    /// <summary>Yük Veren olarak kayıt olur. Rol: Shipper.</summary>
    /// <param name="command">Kayıt bilgileri.</param>
    /// <param name="cancellationToken">İstemci isteği iptal ederse işlem de durur.</param>
    /// <returns>201 ve kullanıcı özeti. Geçersiz alan: 400. E-posta/telefon kayıtlı: 409. Giriş ayrı uçtan yapılır.</returns>
    // POST /api/v1/auth/register/shipper (rol adresten gelir: Shipper)
    [HttpPost("register/shipper")]
    [ProducesResponseType<RegisteredUserDto>(StatusCodes.Status201Created)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> RegisterShipper(RegisterShipperCommand command, CancellationToken cancellationToken) =>
        // 201 Created: yeni hesap oluşturuldu. (Giriş yapılmış sayılmaz; jeton ayrı uçtan alınır.)
        StatusCode(StatusCodes.Status201Created, await registerShipper.HandleAsync(command, cancellationToken));

    /// <summary>Taşımacı olarak kayıt olur (en az 1 araçla). Rol: Carrier.</summary>
    /// <param name="command">Kayıt bilgileri.</param>
    /// <param name="cancellationToken">İstemci isteği iptal ederse işlem de durur.</param>
    /// <returns>201 ve kullanıcı özeti. Geçersiz alan: 400. E-posta/telefon kayıtlı: 409. Giriş ayrı uçtan yapılır.</returns>
    // POST /api/v1/auth/register/carrier (rol adresten gelir: Carrier)
    [HttpPost("register/carrier")]
    [ProducesResponseType<RegisteredUserDto>(StatusCodes.Status201Created)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> RegisterCarrier(RegisterCarrierCommand command, CancellationToken cancellationToken) =>
        // 201 Created: yeni taşımacı hesabı oluşturuldu.
        StatusCode(StatusCodes.Status201Created, await registerCarrier.HandleAsync(command, cancellationToken));
}
