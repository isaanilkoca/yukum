using FluentValidation;
using NSubstitute;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Accounts;
using Yukum.Application.Common;
using Yukum.Domain.Accounts;

namespace Yukum.UnitTests.Application;

// Kayıt handler'ları: doğrula → normalleştir → hesap servisini çağır.
public class RegisterHandlersTests
{
    private readonly IAccountService _accounts = Substitute.For<IAccountService>();
    private readonly RegisterShipperHandler _shipper;
    private readonly RegisterCarrierHandler _carrier;

    public RegisterHandlersTests()
    {
        var geography = Substitute.For<IGeographyRepository>();
        geography.CityExistsAsync(Arg.Any<int>(), Arg.Any<CancellationToken>()).Returns(call => call.Arg<int>() is >= 1 and <= 81);
        _shipper = new RegisterShipperHandler(new RegisterShipperValidator(geography), _accounts);
        _carrier = new RegisterCarrierHandler(new RegisterCarrierValidator(geography), _accounts);
    }

    private static RegisterShipperCommand ShipperCommand() => new(
        "  Ali Veli  ", "  Ali@X.com ", "0532 123 45 67", "Abcdefg1", 33, null, null, null, true);

    [Fact]
    public async Task Shipper_is_normalized_before_it_reaches_the_account_service()
    {
        RegisterShipperCommand? received = null;
        var expected = new RegisteredUserDto(Guid.NewGuid(), "Ali Veli", "ali@x.com", UserType.Shipper);
        _accounts.RegisterShipperAsync(Arg.Do<RegisterShipperCommand>(c => received = c), Arg.Any<CancellationToken>()).Returns(expected);

        var result = await _shipper.HandleAsync(ShipperCommand());

        Assert.Same(expected, result);
        Assert.NotNull(received);
        Assert.Equal("Ali Veli", received.FullName);
        Assert.Equal("ali@x.com", received.Email);
        Assert.Equal("+905321234567", received.Phone);
        Assert.Equal("Abcdefg1", received.Password);   // şifreye dokunulmaz (boşluk/büyük harf anlamlıdır)
    }

    [Fact]
    public async Task An_invalid_shipper_request_never_reaches_the_account_service()
    {
        var error = await Assert.ThrowsAsync<ValidationException>(
            () => _shipper.HandleAsync(ShipperCommand() with { Password = "zayif" }));

        Assert.Contains(error.Errors, e => e.PropertyName == "Password");
        await _accounts.DidNotReceiveWithAnyArgs().RegisterShipperAsync(default!, default);
    }

    [Fact]
    public async Task Carrier_is_normalized_before_it_reaches_the_account_service()
    {
        RegisterCarrierCommand? received = null;
        var expected = new RegisteredUserDto(Guid.NewGuid(), "Veli", "veli@x.com", UserType.Carrier);
        _accounts.RegisterCarrierAsync(Arg.Do<RegisterCarrierCommand>(c => received = c), Arg.Any<CancellationToken>()).Returns(expected);
        var command = new RegisterCarrierCommand(
            " Veli ", "VELI@x.com", "+90 533 222 11 00", "Abcdefg1", 33, [1], [new VehicleInput(VehicleType.Lorry, "  33 ab 1  ", 5000, null)], true);

        var result = await _carrier.HandleAsync(command);

        Assert.Same(expected, result);
        Assert.NotNull(received);
        Assert.Equal("Veli", received.FullName);
        Assert.Equal("veli@x.com", received.Email);
        Assert.Equal("+905332221100", received.Phone);
        Assert.Equal("33 ab 1", received.Vehicles![0].PlateNumber);   // plakanın baş/son boşluğu atılır
    }

    [Fact]
    public async Task An_invalid_carrier_request_never_reaches_the_account_service()
    {
        var command = new RegisterCarrierCommand("Veli", "veli@x.com", "0533 222 11 00", "Abcdefg1", 33, null, [], true);

        await Assert.ThrowsAsync<ValidationException>(() => _carrier.HandleAsync(command));

        await _accounts.DidNotReceiveWithAnyArgs().RegisterCarrierAsync(default!, default);
    }

    [Fact]
    public async Task A_conflict_from_the_account_service_is_not_swallowed()
    {
        _accounts.RegisterShipperAsync(Arg.Any<RegisterShipperCommand>(), Arg.Any<CancellationToken>())
            .Returns<RegisteredUserDto>(_ => throw new ConflictException("Bu e-posta adresiyle zaten bir hesap var."));

        var error = await Assert.ThrowsAsync<ConflictException>(() => _shipper.HandleAsync(ShipperCommand()));

        Assert.Equal("Bu e-posta adresiyle zaten bir hesap var.", error.Message);
    }
}
