using FluentValidation;
using NSubstitute;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Accounts;

namespace Yukum.UnitTests.Application;

// Hesap Bilgilerim (15 Kasım): telefon değişince şifre şartı, temizleme, fotoğraf içerik kontrolü ve eski dosyanın silinmesi.
// IAccountService ve IAvatarStorage sahte (NSubstitute): veritabanı/disk yok, yalnız handler'ın kararları denenir.
public class AccountProfileHandlersTests
{
    private static readonly Guid UserId = Guid.NewGuid();
    private readonly IAccountService _accounts = Substitute.For<IAccountService>();
    private readonly IAvatarStorage _storage = Substitute.For<IAvatarStorage>();
    private readonly UpdateAccountProfileHandler _update;

    public AccountProfileHandlersTests()
    {
        var geography = Substitute.For<IGeographyRepository>();
        geography.CityExistsAsync(Arg.Any<int>(), Arg.Any<CancellationToken>()).Returns(call => call.Arg<int>() is >= 1 and <= 81);
        _update = new UpdateAccountProfileHandler(new UpdateAccountProfileValidator(geography), _accounts);
        // Kayıtlı telefon +905321234567
        _accounts.GetProfileAsync(UserId, Arg.Any<CancellationToken>()).Returns(new AccountProfileDto(
            UserId, "Shipper", "Ali", "ali@x.com", "+905321234567", null, 33, null, null, null, null, null, null, null));
    }

    private static UpdateAccountProfileCommand Command(string phone = "0532 123 45 67", string? password = null) =>
        new(UserId, new UpdateAccountProfileRequest("  Ali Veli ", phone, password, 34, "  ", " Firma ", null, null));

    [Fact]
    public async Task Same_phone_in_another_format_needs_no_password_and_values_are_cleaned()
    {
        UpdateAccountProfileRequest? written = null;
        _accounts.UpdateProfileAsync(UserId, Arg.Do<UpdateAccountProfileRequest>(v => written = v), Arg.Any<CancellationToken>()).Returns(Task.CompletedTask);

        await _update.HandleAsync(Command());

        await _accounts.DidNotReceiveWithAnyArgs().VerifyPasswordAsync(default, default!, default);
        Assert.NotNull(written);
        Assert.Equal("Ali Veli", written.FullName);
        Assert.Equal("+905321234567", written.Phone);
        Assert.Null(written.About);            // yalnız boşluk → null
        Assert.Equal("Firma", written.CompanyName);
    }

    [Fact]
    public async Task Changing_the_phone_without_the_password_is_rejected_before_anything_is_written()
    {
        var error = await Assert.ThrowsAsync<ValidationException>(() => _update.HandleAsync(Command("0533 000 00 00")));
        Assert.Contains(error.Errors, e => e.PropertyName == "currentPassword");
        await _accounts.DidNotReceiveWithAnyArgs().UpdateProfileAsync(default, default!, default);
    }

    [Fact]
    public async Task Changing_the_phone_with_a_wrong_password_is_rejected()
    {
        _accounts.VerifyPasswordAsync(UserId, "Yanlis123", Arg.Any<CancellationToken>()).Returns(false);
        var error = await Assert.ThrowsAsync<ValidationException>(() => _update.HandleAsync(Command("0533 000 00 00", "Yanlis123")));
        Assert.Contains(error.Errors, e => e.ErrorMessage == "Şifre hatalı.");
        await _accounts.DidNotReceiveWithAnyArgs().UpdateProfileAsync(default, default!, default);
    }

    [Fact]
    public async Task Changing_the_phone_with_the_right_password_is_written()
    {
        _accounts.VerifyPasswordAsync(UserId, "Dogru123", Arg.Any<CancellationToken>()).Returns(true);
        await _update.HandleAsync(Command("0533 000 00 00", "Dogru123"));
        await _accounts.Received(1).UpdateProfileAsync(UserId, Arg.Is<UpdateAccountProfileRequest>(v => v.Phone == "+905330000000"), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Field_errors_use_the_names_the_app_sends()
    {
        var bad = new UpdateAccountProfileCommand(UserId, new UpdateAccountProfileRequest("A", "12", null, 99, null, null, "123", null));
        var error = await Assert.ThrowsAsync<ValidationException>(() => _update.HandleAsync(bad));
        Assert.Equal(["cityId", "fullName", "phone", "taxNumber"], error.Errors.Select(e => e.PropertyName).Order().ToArray());
    }

    // ─── Fotoğraf ───

    private static readonly byte[] Jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3];
    private static readonly byte[] Png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1];

    [Fact]
    public void Image_type_comes_from_the_bytes_not_from_the_name()
    {
        Assert.Equal("image/jpeg", AvatarImage.Detect(Jpeg));
        Assert.Equal("image/png", AvatarImage.Detect(Png));
        Assert.Null(AvatarImage.Detect("<script>"u8.ToArray()));   // "foto.jpg" adı taşısa da resim değil
        Assert.Null(AvatarImage.Detect([0xFF, 0xD8]));             // kısa/yarım dosya
    }

    [Fact]
    public void Avatar_url_and_id_round_trip()
    {
        var id = Guid.NewGuid();
        Assert.Equal(id, AvatarPath.IdOf(AvatarPath.For(id)));
        Assert.Null(AvatarPath.IdOf(null));
        Assert.Null(AvatarPath.IdOf("/api/v1/avatars/bozuk"));
    }

    [Fact]
    public async Task A_new_photo_replaces_the_old_file()
    {
        var oldId = Guid.NewGuid(); var newId = Guid.NewGuid();
        _storage.SaveAsync(Png, "image/png", Arg.Any<CancellationToken>()).Returns(newId);
        _accounts.SetAvatarAsync(UserId, AvatarPath.For(newId), Arg.Any<CancellationToken>()).Returns(AvatarPath.For(oldId));

        var url = await new UploadAvatarHandler(_accounts, _storage).HandleAsync(new UploadAvatarCommand(UserId, Png));

        Assert.Equal(AvatarPath.For(newId), url);
        await _storage.Received(1).DeleteAsync(oldId, Arg.Any<CancellationToken>());
        await _storage.DidNotReceive().DeleteAsync(newId, Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task A_file_that_is_not_an_image_or_too_big_is_never_stored()
    {
        var handler = new UploadAvatarHandler(_accounts, _storage);
        await Assert.ThrowsAsync<ValidationException>(() => handler.HandleAsync(new UploadAvatarCommand(UserId, "%PDF-1.4"u8.ToArray())));
        await Assert.ThrowsAsync<ValidationException>(() => handler.HandleAsync(new UploadAvatarCommand(UserId, new byte[AvatarImage.MaxBytes + 1])));
        await _storage.DidNotReceiveWithAnyArgs().SaveAsync(default!, default!, default);
    }

    [Fact]
    public async Task If_the_database_write_fails_the_new_file_is_removed()
    {
        var newId = Guid.NewGuid();
        _storage.SaveAsync(Jpeg, "image/jpeg", Arg.Any<CancellationToken>()).Returns(newId);
        _accounts.SetAvatarAsync(UserId, Arg.Any<string?>(), Arg.Any<CancellationToken>()).Returns<string?>(_ => throw new InvalidOperationException("db"));

        await Assert.ThrowsAsync<InvalidOperationException>(() => new UploadAvatarHandler(_accounts, _storage).HandleAsync(new UploadAvatarCommand(UserId, Jpeg)));
        await _storage.Received(1).DeleteAsync(newId, Arg.Any<CancellationToken>());
    }
}
