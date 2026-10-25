using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Time.Testing;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Accounts;
using Yukum.Application.Common;
using Yukum.Domain.Accounts;
using Yukum.Infrastructure;
using Yukum.Infrastructure.Identity;
using Yukum.Infrastructure.Persistence;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Data;

// Şifre denetimi, hatalı deneme sayacı ve kilit: gerçek SQL Server ve gerçek ASP.NET Core Identity ile.
[Collection("SqlServer")]
public class AuthServiceTests(SqlServerFixture sql)
{
    private const string Password = "Abcdefg1";

    // Identity kilit sürelerini gerçek saatle hesaplar; bu yüzden burada sahte değil gerçek saat kullanılır.
    private static AsyncServiceScope NewScope(TestDatabase db)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddSingleton(TimeProvider.System);
        services.AddScoped<AppDbContext>(_ => db.NewContext());
        services.AddRepositories();
        services.AddAccounts();
        return services.BuildServiceProvider().CreateAsyncScope();
    }

    private async Task<TestDatabase> NewDatabaseWithShipperAsync(string email = "ali@x.com", string phone = "+905321234567")
    {
        var db = await sql.CreateDatabaseAsync(new FakeTimeProvider());
        await using var scope = NewScope(db);
        await scope.ServiceProvider.GetRequiredService<IAccountService>().RegisterShipperAsync(
            new RegisterShipperCommand("Ali Veli", email, phone, Password, 33, null, null, null, true));
        return db;
    }

    private static async Task<AuthUserDto> LoginAsync(TestDatabase db, string? email, string? phone, string password)
    {
        await using var scope = NewScope(db);
        return await scope.ServiceProvider.GetRequiredService<IAuthService>().VerifyCredentialsAsync(email, phone, password);
    }

    [Fact]
    public async Task Login_by_email_returns_the_user_summary()
    {
        var db = await NewDatabaseWithShipperAsync();

        var user = await LoginAsync(db, "ali@x.com", null, Password);

        Assert.Equal("Ali Veli", user.DisplayName);
        Assert.Equal("Shipper", user.Role);
        Assert.Null(user.AvatarUrl);
        Assert.NotEqual(Guid.Empty, user.Id);
    }

    [Fact]
    public async Task Login_by_phone_and_by_email_in_any_letter_case_reach_the_same_user()
    {
        var db = await NewDatabaseWithShipperAsync();

        var byEmail = await LoginAsync(db, "ALI@X.com", null, Password);
        var byPhone = await LoginAsync(db, null, "+905321234567", Password);

        Assert.Equal(byEmail.Id, byPhone.Id);
    }

    [Fact]
    public async Task A_carrier_gets_the_Carrier_role()
    {
        var db = await sql.CreateDatabaseAsync(new FakeTimeProvider());
        await using (var scope = NewScope(db))
            await scope.ServiceProvider.GetRequiredService<IAccountService>().RegisterCarrierAsync(new RegisterCarrierCommand(
                "Veli Nakliyat", "veli@x.com", "+905332221100", Password, 33, null, [new VehicleInput(VehicleType.Truck, null, 1000, null)], true));

        var user = await LoginAsync(db, "veli@x.com", null, Password);

        Assert.Equal("Carrier", user.Role);
    }

    [Fact]
    public async Task A_wrong_password_and_an_unknown_user_are_indistinguishable()
    {
        var db = await NewDatabaseWithShipperAsync();

        var wrongPassword = await Assert.ThrowsAsync<InvalidCredentialsException>(() => LoginAsync(db, "ali@x.com", null, "Yanlis123"));
        var unknownEmail = await Assert.ThrowsAsync<InvalidCredentialsException>(() => LoginAsync(db, "yok@x.com", null, Password));
        var unknownPhone = await Assert.ThrowsAsync<InvalidCredentialsException>(() => LoginAsync(db, null, "+905000000000", Password));

        Assert.Equal("E-posta veya şifre hatalı.", wrongPassword.Message);
        Assert.Equal(wrongPassword.Message, unknownEmail.Message);
        Assert.Equal(wrongPassword.Message, unknownPhone.Message);
    }

    [Fact]
    public async Task The_fifth_wrong_attempt_locks_the_account_for_15_minutes()
    {
        var db = await NewDatabaseWithShipperAsync();

        for (var attempt = 1; attempt <= 4; attempt++)
            await Assert.ThrowsAsync<InvalidCredentialsException>(() => LoginAsync(db, "ali@x.com", null, "Yanlis123"));

        var locked = await Assert.ThrowsAsync<AccountLockedException>(() => LoginAsync(db, "ali@x.com", null, "Yanlis123"));
        Assert.InRange(locked.RetryAfter, TimeSpan.FromMinutes(14), TimeSpan.FromMinutes(15));
    }

    [Fact]
    public async Task While_locked_even_the_correct_password_is_refused()
    {
        var db = await NewDatabaseWithShipperAsync();
        for (var attempt = 1; attempt <= 5; attempt++)
            await Assert.ThrowsAnyAsync<Exception>(() => LoginAsync(db, "ali@x.com", null, "Yanlis123"));

        await Assert.ThrowsAsync<AccountLockedException>(() => LoginAsync(db, "ali@x.com", null, Password));
        await Assert.ThrowsAsync<AccountLockedException>(() => LoginAsync(db, "ali@x.com", null, "Yanlis123"));
    }

    [Fact]
    public async Task After_the_lock_expires_the_correct_password_works_again_and_the_counter_is_reset()
    {
        var db = await NewDatabaseWithShipperAsync();
        for (var attempt = 1; attempt <= 5; attempt++)
            await Assert.ThrowsAnyAsync<Exception>(() => LoginAsync(db, "ali@x.com", null, "Yanlis123"));

        await using (var scope = NewScope(db))   // kilit süresinin dolduğunu simüle et
        {
            var users = scope.ServiceProvider.GetRequiredService<UserManager<AppUser>>();
            var user = (await users.FindByEmailAsync("ali@x.com"))!;
            await users.SetLockoutEndDateAsync(user, DateTimeOffset.UtcNow.AddMinutes(-1));
        }

        Assert.Equal("Ali Veli", (await LoginAsync(db, "ali@x.com", null, Password)).DisplayName);

        await using var read = NewScope(db);
        var after = (await read.ServiceProvider.GetRequiredService<UserManager<AppUser>>().FindByEmailAsync("ali@x.com"))!;
        Assert.Equal(0, after.AccessFailedCount);
    }

    [Fact]
    public async Task A_successful_login_resets_the_failed_attempt_counter()
    {
        var db = await NewDatabaseWithShipperAsync();
        for (var attempt = 1; attempt <= 3; attempt++)
            await Assert.ThrowsAsync<InvalidCredentialsException>(() => LoginAsync(db, "ali@x.com", null, "Yanlis123"));

        await LoginAsync(db, "ali@x.com", null, Password);

        // Sayaç sıfırlandı: yine 4 hatalı deneme kilit açmaz, beşincisi açar.
        for (var attempt = 1; attempt <= 4; attempt++)
            await Assert.ThrowsAsync<InvalidCredentialsException>(() => LoginAsync(db, "ali@x.com", null, "Yanlis123"));
        await Assert.ThrowsAsync<AccountLockedException>(() => LoginAsync(db, "ali@x.com", null, "Yanlis123"));
    }

    [Fact]
    public async Task New_accounts_can_be_locked_at_all()
    {
        var db = await NewDatabaseWithShipperAsync();
        await using var scope = NewScope(db);

        var user = (await scope.ServiceProvider.GetRequiredService<UserManager<AppUser>>().FindByEmailAsync("ali@x.com"))!;

        Assert.True(user.LockoutEnabled);
    }

    [Theory]
    [InlineData(false, false)]   // pasif hesap
    [InlineData(true, true)]     // engellenmiş hesap
    public async Task A_disabled_or_blocked_account_is_forbidden_after_the_correct_password(bool isActive, bool isBlocked)
    {
        var db = await NewDatabaseWithShipperAsync();
        await using (var context = db.NewContext())
        {
            var user = await context.Users.SingleAsync();
            user.IsActive = isActive;
            user.IsBlocked = isBlocked;
            await context.SaveChangesAsync();
        }

        var error = await Assert.ThrowsAsync<ForbiddenException>(() => LoginAsync(db, "ali@x.com", null, Password));
        Assert.Equal("Hesabınız şu an kullanılamıyor. Lütfen destek ile iletişime geçin.", error.Message);
    }

    [Fact]
    public async Task A_blocked_account_with_a_wrong_password_looks_like_any_wrong_password()
    {
        var db = await NewDatabaseWithShipperAsync();
        await using (var context = db.NewContext())
        {
            (await context.Users.SingleAsync()).IsBlocked = true;
            await context.SaveChangesAsync();
        }

        await Assert.ThrowsAsync<InvalidCredentialsException>(() => LoginAsync(db, "ali@x.com", null, "Yanlis123"));
    }
}
