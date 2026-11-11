using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Accounts;

namespace Yukum.Api.Controllers;

/// <summary>Hesap işlemleri (giriş yapmış kullanıcının kendisi için).</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/account")]
[Authorize] // iki rol de
public class AccountController(ICommandHandler<DeleteAccountCommand, bool> deleteAccount) : ControllerBase
{
    /// <summary>Hesabı siler (anonimleştirir). Şifre onayı ister; devam eden işi olan kullanıcı silemez.</summary>
    // POST /api/v1/account/delete  gövde: { "password": "..." }
    // FONKSİYON ROLÜ: API'NİN KAPISI | iOS'taki AccountService.delete'in isteğini karşılar | DELETE yerine POST: gövde (şifre) taşıyan silme isteklerini bazı istemci/araçlar düşürür
    // Hız sınırı "auth" politikası: çalınmış jetonla şifre tahmin etme denemesini yavaşlatır
    [HttpPost("delete")]
    [EnableRateLimiting("auth")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Delete(DeleteAccountRequest request, CancellationToken cancellationToken)
    {
        await deleteAccount.HandleAsync(new DeleteAccountCommand(Guid.Parse(User.FindFirst("sub")!.Value), request.Password), cancellationToken);
        return NoContent();
    }
}
