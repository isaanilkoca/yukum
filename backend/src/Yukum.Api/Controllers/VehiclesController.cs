using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Vehicles;
using Yukum.Domain.Accounts;

namespace Yukum.Api.Controllers;

/// <summary>Araçlarım (15 Kasım): Taşımacı kendi araçlarını listeler, ekler, düzenler, siler. Kurallar: Application/Vehicles/VehicleHandlers.cs.</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/vehicles")]
[Authorize(Roles = RoleNames.Carrier)] // yalnız Taşımacı
public class VehiclesController(
    IQueryHandler<ListVehiclesQuery, IReadOnlyList<VehicleDto>> list,
    ICommandHandler<SaveVehicleCommand, VehicleDto> save,
    ICommandHandler<DeleteVehicleCommand, bool> delete) : ControllerBase
{
    /// <summary>Araçlarım (eklenme sırasıyla).</summary>
    // GET /api/v1/vehicles
    [HttpGet]
    [ProducesResponseType<IReadOnlyList<VehicleDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Mine(CancellationToken cancellationToken) =>
        Ok(await list.HandleAsync(new ListVehiclesQuery(CurrentUserId), cancellationToken));

    /// <summary>Araç ekler. Plaka zorunlu ve Türkiye biçiminde; aynı plaka iki kez olmaz (409).</summary>
    // POST /api/v1/vehicles
    [HttpPost]
    [ProducesResponseType<VehicleDto>(StatusCodes.Status201Created)]
    public async Task<IActionResult> Add(VehicleBody body, CancellationToken cancellationToken) =>
        StatusCode(StatusCodes.Status201Created, await save.HandleAsync(new SaveVehicleCommand(CurrentUserId, null, body), cancellationToken));

    /// <summary>Aracı düzenler (yalnız kendi aracı; başkasınınki 404).</summary>
    // PUT /api/v1/vehicles/{id}
    [HttpPut("{id:guid}")]
    [ProducesResponseType<VehicleDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Update(Guid id, VehicleBody body, CancellationToken cancellationToken) =>
        Ok(await save.HandleAsync(new SaveVehicleCommand(CurrentUserId, id, body), cancellationToken));

    /// <summary>Aracı siler.</summary>
    // DELETE /api/v1/vehicles/{id}
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Remove(Guid id, CancellationToken cancellationToken)
    {
        await delete.HandleAsync(new DeleteVehicleCommand(CurrentUserId, id), cancellationToken);
        return NoContent();
    }

    private Guid CurrentUserId => Guid.Parse(User.FindFirst("sub")!.Value);
}
