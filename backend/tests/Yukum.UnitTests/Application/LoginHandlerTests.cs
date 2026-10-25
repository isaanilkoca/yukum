using FluentValidation;
using NSubstitute;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Accounts;
using Yukum.Application.Common;

namespace Yukum.UnitTests.Application;

// Giriş handler'ı: doğrula → kimliği çöz (e-posta/telefon) → şifreyi denetle → jeton üret.
public class LoginHandlerTests
{
    private static readonly DateTime Expires = new(2026, 10, 25, 9, 15, 0, DateTimeKind.Utc);
    private static readonly AuthUserDto User = new(Guid.NewGuid(), "Ali Veli", "Shipper", null);

    private readonly IAuthService _auth = Substitute.For<IAuthService>();
    private readonly ITokenService _tokens = Substitute.For<ITokenService>();
    private readonly LoginHandler _handler;

    public LoginHandlerTests()
    {
        _tokens.CreateAccessToken(Arg.Any<AuthUserDto>()).Returns(new AccessToken("jwt-degeri", Expires));
        _handler = new LoginHandler(new LoginValidator(), _auth, _tokens);
    }

    private static LoginCommand Command(string emailOrPhone, string password = "Abcdefg1") =>
        new(emailOrPhone, password, "device-1", "iPhone");

    [Fact]
    public async Task Email_login_trims_and_lowercases_and_returns_the_token_and_user()
    {
        _auth.VerifyCredentialsAsync("ali@x.com", null, "Abcdefg1", Arg.Any<CancellationToken>()).Returns(User);

        var response = await _handler.HandleAsync(Command("  ALI@X.com "));

        Assert.Equal("jwt-degeri", response.AccessToken);
        Assert.Equal(Expires, response.AccessTokenExpiresAt);
        Assert.Same(User, response.User);
        _tokens.Received(1).CreateAccessToken(User);
    }

    [Theory]
    [InlineData("0532 123 45 67")]
    [InlineData("+90 532 123 45 67")]
    [InlineData("532-123-45-67")]
    public async Task Phone_login_is_normalized_to_plus90_whatever_the_format(string typed)
    {
        _auth.VerifyCredentialsAsync(null, "+905321234567", "Abcdefg1", Arg.Any<CancellationToken>()).Returns(User);

        var response = await _handler.HandleAsync(Command(typed));

        Assert.Same(User, response.User);
    }

    [Fact]
    public async Task The_password_is_passed_exactly_as_typed()
    {
        _auth.VerifyCredentialsAsync(Arg.Any<string?>(), Arg.Any<string?>(), " Abc Def1 ", Arg.Any<CancellationToken>()).Returns(User);

        await _handler.HandleAsync(Command("ali@x.com", " Abc Def1 "));

        await _auth.Received(1).VerifyCredentialsAsync("ali@x.com", null, " Abc Def1 ", Arg.Any<CancellationToken>());
    }

    [Theory]
    [InlineData("abc")]
    [InlineData("123")]
    [InlineData("02121234567")]
    public async Task An_identifier_that_is_neither_email_nor_mobile_is_just_bad_credentials(string typed)
    {
        await Assert.ThrowsAsync<InvalidCredentialsException>(() => _handler.HandleAsync(Command(typed)));

        await _auth.DidNotReceiveWithAnyArgs().VerifyCredentialsAsync(default, default, default!, default);
        _tokens.DidNotReceiveWithAnyArgs().CreateAccessToken(default!);
    }

    [Fact]
    public async Task An_incomplete_request_is_a_validation_error_and_nothing_else_runs()
    {
        await Assert.ThrowsAsync<ValidationException>(() => _handler.HandleAsync(new LoginCommand(null, null, null, null)));

        await _auth.DidNotReceiveWithAnyArgs().VerifyCredentialsAsync(default, default, default!, default);
    }

    [Fact]
    public async Task Failures_from_the_auth_service_pass_through_and_no_token_is_created()
    {
        _auth.VerifyCredentialsAsync(Arg.Any<string?>(), Arg.Any<string?>(), Arg.Any<string>(), Arg.Any<CancellationToken>())
            .Returns<AuthUserDto>(
                _ => throw new InvalidCredentialsException(),
                _ => throw new AccountLockedException(TimeSpan.FromMinutes(15)),
                _ => throw new ForbiddenException("Hesabınız şu an kullanılamıyor."));

        await Assert.ThrowsAsync<InvalidCredentialsException>(() => _handler.HandleAsync(Command("ali@x.com")));
        var locked = await Assert.ThrowsAsync<AccountLockedException>(() => _handler.HandleAsync(Command("ali@x.com")));
        await Assert.ThrowsAsync<ForbiddenException>(() => _handler.HandleAsync(Command("ali@x.com")));

        Assert.Equal(TimeSpan.FromMinutes(15), locked.RetryAfter);
        _tokens.DidNotReceiveWithAnyArgs().CreateAccessToken(default!);
    }
}
