using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Accounts;

namespace Yukum.Api.Controllers;

/// <summary>
/// Kayıt ve (sonraki adımlarda) giriş uçları. Hepsi anonimdir: kullanıcı henüz giriş yapmamıştır.
/// İki kullanıcı türü için iki ayrı kayıt ucu vardır; rolü endpoint'in kendisi belirler, istemciden rol alanı gelmez.
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/auth")]
[AllowAnonymous]
public class AuthController(
    ICommandHandler<RegisterShipperCommand, RegisteredUserDto> registerShipper,
    ICommandHandler<RegisterCarrierCommand, RegisteredUserDto> registerCarrier) : ControllerBase
{
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
