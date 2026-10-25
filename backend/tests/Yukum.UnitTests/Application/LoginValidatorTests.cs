using FluentValidation.TestHelper;
using Yukum.Application.Accounts;

namespace Yukum.UnitTests.Application;

// Giriş isteği: yalnız "alan dolu mu" bakılır. Şifre karmaşıklığı burada denetlenmez (kayıt kuralı değişse bile eski kullanıcı girebilsin).
public class LoginValidatorTests
{
    private readonly LoginValidator _validator = new();

    private static LoginCommand Valid() => new("ali@x.com", "Abcdefg1", "device-1", "Anıl'ın iPhone'u");

    [Fact]
    public async Task A_complete_request_passes_and_device_name_is_optional()
    {
        (await _validator.TestValidateAsync(Valid())).ShouldNotHaveAnyValidationErrors();
        (await _validator.TestValidateAsync(Valid() with { DeviceName = null })).ShouldNotHaveAnyValidationErrors();
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task Email_or_phone_is_required(string? value)
    {
        var result = await _validator.TestValidateAsync(Valid() with { EmailOrPhone = value });
        result.ShouldHaveValidationErrorFor(c => c.EmailOrPhone).WithErrorMessage("E-posta veya telefon boş olamaz.");
    }

    [Fact]
    public async Task Email_or_phone_has_a_length_limit()
    {
        var result = await _validator.TestValidateAsync(Valid() with { EmailOrPhone = new string('a', 255) });
        result.ShouldHaveValidationErrorFor(c => c.EmailOrPhone).WithErrorMessage("E-posta veya telefon en fazla 254 karakter olabilir.");
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task Password_is_required(string? value)
    {
        var result = await _validator.TestValidateAsync(Valid() with { Password = value });
        result.ShouldHaveValidationErrorFor(c => c.Password).WithErrorMessage("Şifre boş olamaz.");
    }

    [Fact]
    public async Task Password_longer_than_128_is_rejected_before_it_reaches_the_hasher()
    {
        var result = await _validator.TestValidateAsync(Valid() with { Password = new string('a', 129) });
        result.ShouldHaveValidationErrorFor(c => c.Password).WithErrorMessage("Şifre en fazla 128 karakter olabilir.");
    }

    [Fact]
    public async Task A_weak_password_is_not_rejected_at_login()
    {
        var result = await _validator.TestValidateAsync(Valid() with { Password = "abc" });
        result.ShouldNotHaveValidationErrorFor(c => c.Password);
    }

    [Theory]
    [InlineData(null, "Cihaz kimliği boş olamaz.")]
    [InlineData("", "Cihaz kimliği boş olamaz.")]
    public async Task Device_id_is_required(string? value, string message)
    {
        var result = await _validator.TestValidateAsync(Valid() with { DeviceId = value });
        result.ShouldHaveValidationErrorFor(c => c.DeviceId).WithErrorMessage(message);
    }

    [Fact]
    public async Task Device_id_and_name_have_length_limits()
    {
        var result = await _validator.TestValidateAsync(Valid() with { DeviceId = new string('a', 101), DeviceName = new string('b', 101) });
        result.ShouldHaveValidationErrorFor(c => c.DeviceId).WithErrorMessage("Cihaz kimliği en fazla 100 karakter olabilir.");
        result.ShouldHaveValidationErrorFor(c => c.DeviceName).WithErrorMessage("Cihaz adı en fazla 100 karakter olabilir.");
    }
}
