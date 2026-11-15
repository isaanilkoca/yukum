using System.Text.RegularExpressions;
using FluentValidation;
using FluentValidation.Results;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Domain.Accounts;

namespace Yukum.Application.Vehicles;

// ─── ARAÇLARIM (15 Kasım, yönetici: "içerde araç kaydetme sayfası olmalı; birden fazla aracı olabilir; plakası ve türüne göre kaydedip
//      araçlarım sayfası olmalı, düzenleyebilmeli; plaka bilgisi de alınmalı") ──────────────────────────────────────────────
// KURALLAR: plaka ZORUNLU + Türkiye biçimi (il kodu 01-81, 1-3 harf, 2-5 rakam) ve tek biçime çevrilir ("34abc123" → "34 ABC 123");
//   aynı plaka iki kez kayıtlı olamaz (silinmiş hesapların plakası zaten silinir); tür zorunlu; kapasite isteğe bağlı (0 < kg ≤ 100.000).
//   Bir Taşımacı en çok 20 araç. Yalnız kendi araçlarını görür/değiştirir (başkasınınki 404).
// TEKLİF: aracı olmayan Taşımacı teklif veremez (CreateOfferHandler).

// 15 Kasım: Brand/Model/Year eklendi (zorunlu). Eski kayıtta boş gelebilir → iOS "bilgileri tamamla" uyarısı gösterir.
public sealed record VehicleBody(VehicleType? Type, string? PlateNumber, int? CapacityKg, string? Brand, string? Model, int? Year);
public sealed record VehicleDto(Guid Id, VehicleType Type, string PlateNumber, int? CapacityKg, string? Brand, string? Model, int? Year);
public sealed record ListVehiclesQuery(Guid CarrierId);
public sealed record SaveVehicleCommand(Guid CarrierId, Guid? VehicleId, VehicleBody Body); // VehicleId null → yeni araç
public sealed record DeleteVehicleCommand(Guid CarrierId, Guid VehicleId);

public static partial class PlateNumber
{
    [GeneratedRegex("^(0[1-9]|[1-7][0-9]|8[01])([A-Z]{1,3})([0-9]{2,5})$")]
    private static partial Regex Pattern();

    /// <summary>Plakayı tek biçime çevirir: boşluklar atılır, büyük harf, "34 ABC 123". Geçersizse null.</summary>
    public static string? Normalize(string? input)
    {
        if (string.IsNullOrWhiteSpace(input)) return null;
        var compact = new string(input.Where(c => !char.IsWhiteSpace(c) && c != '-').ToArray()).ToUpperInvariant()
            .Replace('İ', 'I'); // Türkçe klavyede "i" → "İ" olabilir; plakada noktasız I
        var m = Pattern().Match(compact);
        return m.Success ? $"{m.Groups[1].Value} {m.Groups[2].Value} {m.Groups[3].Value}" : null;
    }
}

public sealed class ListVehiclesHandler(IRepository<Vehicle> vehicles) : IQueryHandler<ListVehiclesQuery, IReadOnlyList<VehicleDto>>
{
    public async Task<IReadOnlyList<VehicleDto>> HandleAsync(ListVehiclesQuery query, CancellationToken cancellationToken = default) =>
        (await vehicles.ListAsync(v => v.CarrierId == query.CarrierId, asNoTracking: true, cancellationToken))
            .OrderBy(v => v.CreatedAt)
            .Select(v => new VehicleDto(v.Id, v.Type, v.PlateNumber ?? "", v.CapacityKg, v.Brand, v.Model, v.Year)).ToList();
}

public sealed class SaveVehicleHandler(IRepository<Vehicle> vehicles, IUnitOfWork unitOfWork) : ICommandHandler<SaveVehicleCommand, VehicleDto>
{
    public async Task<VehicleDto> HandleAsync(SaveVehicleCommand command, CancellationToken cancellationToken = default)
    {
        var b = command.Body;
        var errors = new List<ValidationFailure>();
        // "Farketmez" (Any) yalnız ilanda anlamlı; bir aracın türü olamaz (15 Kasım)
        if (b.Type is null || !Enum.IsDefined(b.Type.Value) || b.Type == VehicleType.Any) errors.Add(new("Type", "Araç türünü seç."));
        var plate = PlateNumber.Normalize(b.PlateNumber);
        if (string.IsNullOrWhiteSpace(b.PlateNumber)) errors.Add(new("PlateNumber", "Plaka zorunlu."));
        else if (plate is null) errors.Add(new("PlateNumber", "Plaka geçersiz. Örnek: 34 ABC 123"));
        if (b.CapacityKg is { } kg && (kg <= 0 || kg > 100_000)) errors.Add(new("CapacityKg", "Kapasite 1 ile 100.000 kg arasında olmalı."));
        // Marka / model / yıl ZORUNLU (15 Kasım): Yük Veren teklifte ve Taşımacı profilinde aracın kalitesini (yaşını) görür.
        if (string.IsNullOrWhiteSpace(b.Brand)) errors.Add(new("Brand", "Marka zorunlu."));
        else if (b.Brand.Trim().Length > 50) errors.Add(new("Brand", "Marka en fazla 50 karakter olabilir."));
        if (string.IsNullOrWhiteSpace(b.Model)) errors.Add(new("Model", "Model zorunlu."));
        else if (b.Model.Trim().Length > 50) errors.Add(new("Model", "Model en fazla 50 karakter olabilir."));
        var maxYear = DateTime.UtcNow.Year + 1; // gelecek yılın modeli bu yıl satılabilir
        if (b.Year is null) errors.Add(new("Year", "Model yılı zorunlu."));
        else if (b.Year < 1970 || b.Year > maxYear) errors.Add(new("Year", $"Model yılı 1970 ile {maxYear} arasında olmalı."));
        if (errors.Count > 0) throw new ValidationException(errors);

        // Aynı plaka başka bir araçta (bu Taşımacı ya da başkası) kayıtlı mı?
        if (await vehicles.AnyAsync(v => v.PlateNumber == plate && v.Id != (command.VehicleId ?? Guid.Empty), cancellationToken))
            throw new ConflictException("Bu plaka zaten kayıtlı.");

        Vehicle vehicle;
        if (command.VehicleId is { } id)
        {
            vehicle = await vehicles.GetByIdAsync(id, asNoTracking: false, cancellationToken) is { } v && v.CarrierId == command.CarrierId
                ? v : throw new NotFoundException("Araç bulunamadı.");
        }
        else
        {
            if (await vehicles.CountAsync(v => v.CarrierId == command.CarrierId, cancellationToken) >= 20)
                throw new ConflictException("En fazla 20 araç ekleyebilirsin.");
            vehicle = new Vehicle { CarrierId = command.CarrierId };
            vehicles.Add(vehicle);
        }
        vehicle.Type = b.Type!.Value;
        vehicle.PlateNumber = plate;
        vehicle.CapacityKg = b.CapacityKg;
        vehicle.Brand = b.Brand!.Trim();
        vehicle.Model = b.Model!.Trim();
        vehicle.Year = b.Year;
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return new VehicleDto(vehicle.Id, vehicle.Type, vehicle.PlateNumber!, vehicle.CapacityKg, vehicle.Brand, vehicle.Model, vehicle.Year);
    }
}

public sealed class DeleteVehicleHandler(IRepository<Vehicle> vehicles, IUnitOfWork unitOfWork) : ICommandHandler<DeleteVehicleCommand, bool>
{
    public async Task<bool> HandleAsync(DeleteVehicleCommand command, CancellationToken cancellationToken = default)
    {
        var vehicle = await vehicles.GetByIdAsync(command.VehicleId, asNoTracking: false, cancellationToken);
        if (vehicle is null || vehicle.CarrierId != command.CarrierId) throw new NotFoundException("Araç bulunamadı.");
        vehicles.Remove(vehicle);
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return true;
    }
}
