using FluentValidation.TestHelper;
using NSubstitute;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Accounts;
using Yukum.Domain.Accounts;

namespace Yukum.UnitTests.Application;

// Taşımacı kayıt kuralları: ortak kurallar + araç, merkez il ve çalışma illeri.
public class RegisterCarrierValidatorTests
{
    private readonly RegisterCarrierValidator _validator;

    public RegisterCarrierValidatorTests()
    {
        var geography = Substitute.For<IGeographyRepository>();
        geography.CityExistsAsync(Arg.Any<int>(), Arg.Any<CancellationToken>()).Returns(call => call.Arg<int>() is >= 1 and <= 81);
        _validator = new RegisterCarrierValidator(geography);
    }

    private static VehicleInput Truck() => new(VehicleType.Truck, "33 ABC 123", 24000, 90m);

    private static RegisterCarrierCommand Valid() => new(
        "Veli Nakliyat", "veli@x.com", "0533 222 11 00", "Abcdefg1", 33, [33, 1], [Truck()], true);

    [Fact]
    public async Task A_complete_valid_request_passes()
    {
        var result = await _validator.TestValidateAsync(Valid());
        result.ShouldNotHaveAnyValidationErrors();
    }

    [Fact]
    public async Task Service_cities_and_vehicle_plate_and_volume_are_optional()
    {
        var command = Valid() with
        {
            ServiceCityIds = null,
            Vehicles = [new VehicleInput(VehicleType.Pickup, null, 1500, null)]
        };

        (await _validator.TestValidateAsync(command)).ShouldNotHaveAnyValidationErrors();
    }

    [Fact]
    public async Task Shared_account_rules_apply_to_carriers_too()
    {
        var result = await _validator.TestValidateAsync(
            Valid() with { FullName = null, Email = "yok", Phone = "1", Password = "abc", KvkkAccepted = false });

        result.ShouldHaveValidationErrorFor(c => c.FullName).WithErrorMessage("Ad soyad boş olamaz.");
        result.ShouldHaveValidationErrorFor(c => c.Email).WithErrorMessage("Geçerli bir e-posta adresi girin.");
        result.ShouldHaveValidationErrorFor(c => c.Phone).WithErrorMessage("Geçerli bir cep telefonu numarası girin (örn. 0532 123 45 67).");
        result.ShouldHaveValidationErrorFor(c => c.Password).WithErrorMessage("Şifre en az 8 karakter olmalı.");
        result.ShouldHaveValidationErrorFor(c => c.KvkkAccepted);
    }

    // ---------- merkez il ve çalışma illeri ----------
    [Fact]
    public async Task Home_city_is_required_and_must_exist()
    {
        (await _validator.TestValidateAsync(Valid() with { HomeCityId = null }))
            .ShouldHaveValidationErrorFor(c => c.HomeCityId).WithErrorMessage("İl seçin.");
        (await _validator.TestValidateAsync(Valid() with { HomeCityId = 999 }))
            .ShouldHaveValidationErrorFor(c => c.HomeCityId).WithErrorMessage("Geçerli bir il seçin.");
    }

    [Fact]
    public async Task A_service_city_that_does_not_exist_is_rejected()
    {
        var result = await _validator.TestValidateAsync(Valid() with { ServiceCityIds = [33, 999] });
        result.ShouldHaveValidationErrorFor("ServiceCityIds[1]").WithErrorMessage("Geçersiz il seçimi.");
    }

    [Fact]
    public async Task The_same_service_city_twice_is_rejected()
    {
        var result = await _validator.TestValidateAsync(Valid() with { ServiceCityIds = [33, 1, 33] });
        result.ShouldHaveValidationErrorFor(c => c.ServiceCityIds).WithErrorMessage("Aynı il birden fazla seçilmiş.");
    }

    // ---------- araçlar ----------
    [Fact]
    public async Task At_least_one_vehicle_is_required()
    {
        (await _validator.TestValidateAsync(Valid() with { Vehicles = null }))
            .ShouldHaveValidationErrorFor(c => c.Vehicles).WithErrorMessage("En az bir araç eklemelisiniz.");
        (await _validator.TestValidateAsync(Valid() with { Vehicles = [] }))
            .ShouldHaveValidationErrorFor(c => c.Vehicles).WithErrorMessage("En az bir araç eklemelisiniz.");
    }

    [Fact]
    public async Task More_than_20_vehicles_are_rejected()
    {
        var result = await _validator.TestValidateAsync(Valid() with { Vehicles = Enumerable.Range(0, 21).Select(_ => Truck()).ToList() });
        result.ShouldHaveValidationErrorFor(c => c.Vehicles).WithErrorMessage("En fazla 20 araç eklenebilir.");
    }

    [Fact]
    public async Task Vehicle_type_is_required_and_must_be_a_known_type()
    {
        (await _validator.TestValidateAsync(Valid() with { Vehicles = [Truck() with { Type = null }] }))
            .ShouldHaveValidationErrorFor("Vehicles[0].Type").WithErrorMessage("Araç tipi seçin.");
        (await _validator.TestValidateAsync(Valid() with { Vehicles = [Truck() with { Type = (VehicleType)42 }] }))
            .ShouldHaveValidationErrorFor("Vehicles[0].Type").WithErrorMessage("Geçerli bir araç tipi seçin.");
    }

    [Theory]
    [InlineData(null, "Taşıma kapasitesi girin.")]
    [InlineData(0, "Taşıma kapasitesi 0'dan büyük olmalı.")]
    [InlineData(-5, "Taşıma kapasitesi 0'dan büyük olmalı.")]
    [InlineData(100001, "Taşıma kapasitesi en fazla 100.000 kg olabilir.")]
    public async Task Vehicle_capacity_rules(int? capacityKg, string message)
    {
        var result = await _validator.TestValidateAsync(Valid() with { Vehicles = [Truck() with { CapacityKg = capacityKg }] });
        result.ShouldHaveValidationErrorFor("Vehicles[0].CapacityKg").WithErrorMessage(message);
    }

    [Fact]
    public async Task Vehicle_plate_and_volume_rules()
    {
        var result = await _validator.TestValidateAsync(
            Valid() with { Vehicles = [Truck() with { PlateNumber = new string('x', 21), CapacityVolume = 0m }] });

        result.ShouldHaveValidationErrorFor("Vehicles[0].PlateNumber").WithErrorMessage("Plaka en fazla 20 karakter olabilir.");
        result.ShouldHaveValidationErrorFor("Vehicles[0].CapacityVolume").WithErrorMessage("Hacim 0'dan büyük olmalı.");

        var tooBig = await _validator.TestValidateAsync(Valid() with { Vehicles = [Truck() with { CapacityVolume = 201m }] });
        tooBig.ShouldHaveValidationErrorFor("Vehicles[0].CapacityVolume").WithErrorMessage("Hacim en fazla 200 m³ olabilir.");
    }

    [Fact]
    public async Task The_error_points_at_the_exact_vehicle()
    {
        var result = await _validator.TestValidateAsync(Valid() with { Vehicles = [Truck(), Truck() with { CapacityKg = 0 }] });

        result.ShouldNotHaveValidationErrorFor("Vehicles[0].CapacityKg");
        result.ShouldHaveValidationErrorFor("Vehicles[1].CapacityKg");
    }
}
