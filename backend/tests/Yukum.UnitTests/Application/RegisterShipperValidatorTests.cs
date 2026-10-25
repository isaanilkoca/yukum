using FluentValidation.TestHelper;
using NSubstitute;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Accounts;

namespace Yukum.UnitTests.Application;

// Yük Veren kayıt kuralları ve Türkçe mesajları.
public class RegisterShipperValidatorTests
{
    private readonly RegisterShipperValidator _validator;

    public RegisterShipperValidatorTests()
    {
        var geography = Substitute.For<IGeographyRepository>();
        geography.CityExistsAsync(Arg.Any<int>(), Arg.Any<CancellationToken>()).Returns(call => call.Arg<int>() is >= 1 and <= 81);
        _validator = new RegisterShipperValidator(geography);
    }

    private static RegisterShipperCommand Valid() => new(
        "Ali Veli", "ali@x.com", "0532 123 45 67", "Abcdefg1", 33, "Ali Tarım", "1234567890", "Mersin", true);

    [Fact]
    public async Task A_complete_valid_request_passes()
    {
        var result = await _validator.TestValidateAsync(Valid());
        result.ShouldNotHaveAnyValidationErrors();
    }

    [Fact]
    public async Task Optional_company_fields_may_be_missing()
    {
        var result = await _validator.TestValidateAsync(Valid() with { CompanyName = null, TaxNumber = null, TaxOffice = null });
        result.ShouldNotHaveAnyValidationErrors();
    }

    // ---------- ortak kurallar ----------
    [Theory]
    [InlineData(null, "Ad soyad boş olamaz.")]
    [InlineData("", "Ad soyad boş olamaz.")]
    [InlineData("   ", "Ad soyad boş olamaz.")]
    [InlineData("A", "Ad soyad en az 2 karakter olmalı.")]
    public async Task FullName_rules(string? value, string message)
    {
        var result = await _validator.TestValidateAsync(Valid() with { FullName = value });
        result.ShouldHaveValidationErrorFor(c => c.FullName).WithErrorMessage(message);
    }

    [Fact]
    public async Task FullName_longer_than_150_is_rejected()
    {
        var result = await _validator.TestValidateAsync(Valid() with { FullName = new string('a', 151) });
        result.ShouldHaveValidationErrorFor(c => c.FullName).WithErrorMessage("Ad soyad en fazla 150 karakter olabilir.");
    }

    [Theory]
    [InlineData(null, "E-posta boş olamaz.")]
    [InlineData("", "E-posta boş olamaz.")]
    [InlineData("yok", "Geçerli bir e-posta adresi girin.")]
    [InlineData("ali@", "Geçerli bir e-posta adresi girin.")]
    [InlineData("ali veli@x.com", "Geçerli bir e-posta adresi girin.")]
    public async Task Email_rules(string? value, string message)
    {
        var result = await _validator.TestValidateAsync(Valid() with { Email = value });
        result.ShouldHaveValidationErrorFor(c => c.Email).WithErrorMessage(message);
    }

    [Fact]
    public async Task Email_longer_than_254_is_rejected()
    {
        var result = await _validator.TestValidateAsync(Valid() with { Email = new string('a', 250) + "@x.com" });
        result.ShouldHaveValidationErrorFor(c => c.Email).WithErrorMessage("E-posta en fazla 254 karakter olabilir.");
    }

    [Theory]
    [InlineData(null, "Telefon numarası boş olamaz.")]
    [InlineData("", "Telefon numarası boş olamaz.")]
    [InlineData("123", "Geçerli bir cep telefonu numarası girin (örn. 0532 123 45 67).")]
    [InlineData("02121234567", "Geçerli bir cep telefonu numarası girin (örn. 0532 123 45 67).")]
    public async Task Phone_rules(string? value, string message)
    {
        var result = await _validator.TestValidateAsync(Valid() with { Phone = value });
        result.ShouldHaveValidationErrorFor(c => c.Phone).WithErrorMessage(message);
    }

    [Theory]
    [InlineData(null, "Şifre boş olamaz.")]
    [InlineData("", "Şifre boş olamaz.")]
    [InlineData("Ab1", "Şifre en az 8 karakter olmalı.")]
    [InlineData("abcdefg1", "Şifre en az bir büyük harf içermeli.")]
    [InlineData("ABCDEFG1", "Şifre en az bir küçük harf içermeli.")]
    [InlineData("Abcdefgh", "Şifre en az bir rakam içermeli.")]
    public async Task Password_rules(string? value, string message)
    {
        var result = await _validator.TestValidateAsync(Valid() with { Password = value });
        result.ShouldHaveValidationErrorFor(c => c.Password).WithErrorMessage(message);
    }

    [Fact]
    public async Task Password_longer_than_128_is_rejected()
    {
        var result = await _validator.TestValidateAsync(Valid() with { Password = "Aa1" + new string('x', 126) });
        result.ShouldHaveValidationErrorFor(c => c.Password).WithErrorMessage("Şifre en fazla 128 karakter olabilir.");
    }

    [Theory]
    [InlineData("Abcdefg1")]
    [InlineData("Şifre1234")]          // Türkçe büyük harf Ş geçerli
    [InlineData("abcdeF12 xyz")]       // boşluk serbest
    [InlineData("Abcdef1!")]           // sembol serbest ama zorunlu değil
    public async Task Common_valid_passwords_pass(string password)
    {
        var result = await _validator.TestValidateAsync(Valid() with { Password = password });
        result.ShouldNotHaveValidationErrorFor(c => c.Password);
    }

    [Fact]
    public async Task Kvkk_must_be_accepted()
    {
        var result = await _validator.TestValidateAsync(Valid() with { KvkkAccepted = false });
        result.ShouldHaveValidationErrorFor(c => c.KvkkAccepted)
            .WithErrorMessage("Devam etmek için KVKK aydınlatma metnini onaylamanız gerekir.");
    }

    // ---------- Yük Veren'e özel ----------
    [Fact]
    public async Task City_is_required()
    {
        var result = await _validator.TestValidateAsync(Valid() with { CityId = null });
        result.ShouldHaveValidationErrorFor(c => c.CityId).WithErrorMessage("İl seçin.");
    }

    [Theory]
    [InlineData(0)]
    [InlineData(82)]
    [InlineData(999)]
    [InlineData(-3)]
    public async Task City_must_exist(int cityId)
    {
        var result = await _validator.TestValidateAsync(Valid() with { CityId = cityId });
        result.ShouldHaveValidationErrorFor(c => c.CityId).WithErrorMessage("Geçerli bir il seçin.");
    }

    [Theory]
    [InlineData("123")]
    [InlineData("12345abcde")]
    [InlineData("123456789012")]
    public async Task Tax_number_must_be_10_or_11_digits(string value)
    {
        var result = await _validator.TestValidateAsync(Valid() with { TaxNumber = value });
        result.ShouldHaveValidationErrorFor(c => c.TaxNumber)
            .WithErrorMessage("Vergi numarası 10 veya 11 haneli rakamlardan oluşmalı.");
    }

    [Theory]
    [InlineData("1234567890")]
    [InlineData("12345678901")]
    public async Task Tax_number_of_10_or_11_digits_passes(string value)
    {
        var result = await _validator.TestValidateAsync(Valid() with { TaxNumber = value });
        result.ShouldNotHaveValidationErrorFor(c => c.TaxNumber);
    }

    [Fact]
    public async Task Company_name_and_tax_office_have_length_limits()
    {
        var result = await _validator.TestValidateAsync(
            Valid() with { CompanyName = new string('a', 201), TaxOffice = new string('b', 101) });

        result.ShouldHaveValidationErrorFor(c => c.CompanyName).WithErrorMessage("Firma adı en fazla 200 karakter olabilir.");
        result.ShouldHaveValidationErrorFor(c => c.TaxOffice).WithErrorMessage("Vergi dairesi en fazla 100 karakter olabilir.");
    }
}
