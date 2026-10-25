using System.ComponentModel.DataAnnotations;
using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Yukum.IntegrationTests.Support;

// YALNIZ TEST: API'nin genel kurallarını (JSON, hata formatı, sürüm) denemek için örnek uçlar. Üretim API'sinde yoktur.
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/test")]
public class TestEndpointsController : ControllerBase
{
    public enum Status { Open, InTransit }

    public record Sample(string UserName, Status CurrentStatus, DateTimeOffset CreatedAt, DateTime UpdatedAt, decimal Price, Guid Id);

    public record EmailRequest([Required, EmailAddress] string? Email);

    [HttpGet("sample")]
    public Sample GetSample() => new(
        "ali",
        Status.InTransit,
        new DateTimeOffset(2026, 10, 20, 10, 15, 0, 987, TimeSpan.FromHours(3)),   // +03:00 ve milisaniyeli: UTC'ye çevrilmeli, kesir atılmalı
        new DateTime(2026, 10, 20, 7, 15, 0, 123, DateTimeKind.Utc),
        1250.50m,
        Guid.Parse("11111111-2222-3333-4444-555555555555"));

    [HttpPost("echo-date")]
    public DateTimeOffset EchoDate([FromBody] DateEcho body) => body.When;

    public record DateEcho(DateTimeOffset When);

    [HttpGet("boom")]
    public IActionResult Boom() => throw new InvalidOperationException("GIZLI-IC-DETAY tablo Users sutun PasswordHash");

    // Jeton ve rol denemeleri için korumalı örnek uçlar.
    [Authorize]
    [HttpGet("secure")]
    public object Secure() => new { sub = User.FindFirst("sub")?.Value, role = User.FindFirst("role")?.Value, isShipper = User.IsInRole("Shipper") };

    [Authorize(Roles = "Admin")]
    [HttpGet("admin-only")]
    public IActionResult AdminOnly() => Ok();

    [Authorize(Roles = "Shipper")]
    [HttpGet("shipper-only")]
    public IActionResult ShipperOnly() => Ok();

    [HttpPost("validate")]
    public IActionResult Validate(EmailRequest request) => Ok(request);
}
