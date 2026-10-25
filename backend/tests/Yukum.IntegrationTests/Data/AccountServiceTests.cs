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

// Hesap oluşturma servisi gerçek SQL Server ve gerçek ASP.NET Core Identity ile: tek işlem, rol, hash, çift kayıt.
[Collection("SqlServer")]
public class AccountServiceTests(SqlServerFixture sql)
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 25, 9, 0, 0, TimeSpan.Zero);

    private static AsyncServiceScope NewScope(TestDatabase db, FakeTimeProvider time)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddSingleton<TimeProvider>(time);
        services.AddScoped<AppDbContext>(_ => db.NewContext());
        services.AddRepositories();
        services.AddAccounts();
        return services.BuildServiceProvider().CreateAsyncScope();
    }

    private async Task<(TestDatabase Db, FakeTimeProvider Time)> NewDatabaseAsync()
    {
        var time = new FakeTimeProvider(T0);
        return (await sql.CreateDatabaseAsync(time), time);
    }

    private static RegisterShipperCommand Shipper(string email = "ali@x.com", string phone = "+905321234567") =>
        new("Ali Veli", email, phone, "Abcdefg1", 33, "Ali Tarım", "1234567890", "Mersin", true);

    private static RegisterCarrierCommand Carrier(string email = "veli@x.com", string phone = "+905332221100", List<int>? serviceCities = null) =>
        new("Veli Nakliyat", email, phone, "Abcdefg1", 33, serviceCities ?? [33, 1],
            [new VehicleInput(VehicleType.Truck, "33 ABC 123", 24000, 90m), new VehicleInput(VehicleType.Refrigerated, null, 8000, null)], true);

    [Fact]
    public async Task Shipper_is_created_with_user_role_and_profile()
    {
        var (db, time) = await NewDatabaseAsync();
        RegisteredUserDto dto;
        await using (var scope = NewScope(db, time))
            dto = await scope.ServiceProvider.GetRequiredService<IAccountService>().RegisterShipperAsync(Shipper());

        Assert.Equal("ali@x.com", dto.Email);
        Assert.Equal("Ali Veli", dto.FullName);
        Assert.Equal(UserType.Shipper, dto.UserType);

        await using var read = NewScope(db, time);
        var users = read.ServiceProvider.GetRequiredService<UserManager<AppUser>>();
        var user = await users.FindByIdAsync(dto.Id.ToString());
        Assert.NotNull(user);
        Assert.Equal("ali@x.com", user.UserName);
        Assert.Equal("+905321234567", user.PhoneNumber);
        Assert.Equal(UserType.Shipper, user.UserType);
        Assert.True(user.IsActive);
        Assert.False(user.IsBlocked);
        Assert.Equal(T0.UtcDateTime, user.KvkkAcceptedAt);
        Assert.Equal(T0.UtcDateTime, user.CreatedAt);
        Assert.True(await users.IsInRoleAsync(user, RoleNames.Shipper));
        Assert.False(await users.IsInRoleAsync(user, RoleNames.Carrier));
        Assert.False(await users.IsInRoleAsync(user, RoleNames.Admin));

        var context = read.ServiceProvider.GetRequiredService<AppDbContext>();
        var profile = await context.ShipperProfiles.SingleAsync(p => p.UserId == dto.Id);
        Assert.Equal("Ali Tarım", profile.CompanyName);
        Assert.Equal("1234567890", profile.TaxNumber);
        Assert.Equal("Mersin", profile.TaxOffice);
        Assert.Equal(33, profile.CityId);
    }

    [Fact]
    public async Task The_password_is_hashed_never_stored_and_can_be_verified()
    {
        var (db, time) = await NewDatabaseAsync();
        RegisteredUserDto dto;
        await using (var scope = NewScope(db, time))
            dto = await scope.ServiceProvider.GetRequiredService<IAccountService>().RegisterShipperAsync(Shipper());

        await using var read = NewScope(db, time);
        var users = read.ServiceProvider.GetRequiredService<UserManager<AppUser>>();
        var user = (await users.FindByIdAsync(dto.Id.ToString()))!;

        Assert.False(string.IsNullOrEmpty(user.PasswordHash));
        Assert.DoesNotContain("Abcdefg1", user.PasswordHash);
        Assert.True(await users.CheckPasswordAsync(user, "Abcdefg1"));
        Assert.False(await users.CheckPasswordAsync(user, "Abcdefg2"));
    }

    [Fact]
    public async Task Carrier_is_created_with_role_profile_vehicles_and_service_cities()
    {
        var (db, time) = await NewDatabaseAsync();
        RegisteredUserDto dto;
        await using (var scope = NewScope(db, time))
            dto = await scope.ServiceProvider.GetRequiredService<IAccountService>().RegisterCarrierAsync(Carrier());

        Assert.Equal(UserType.Carrier, dto.UserType);

        await using var read = NewScope(db, time);
        var users = read.ServiceProvider.GetRequiredService<UserManager<AppUser>>();
        var user = (await users.FindByIdAsync(dto.Id.ToString()))!;
        Assert.True(await users.IsInRoleAsync(user, RoleNames.Carrier));
        Assert.False(await users.IsInRoleAsync(user, RoleNames.Shipper));

        var context = read.ServiceProvider.GetRequiredService<AppDbContext>();
        var profile = await context.CarrierProfiles.Include(p => p.Vehicles).Include(p => p.ServiceCities).SingleAsync(p => p.UserId == dto.Id);
        Assert.Equal(33, profile.HomeCityId);
        Assert.True(profile.IsAvailable);
        Assert.Equal(2, profile.Vehicles.Count);
        Assert.Contains(profile.Vehicles, v => v.Type == VehicleType.Truck && v.PlateNumber == "33 ABC 123" && v.CapacityKg == 24000 && v.CapacityVolume == 90m);
        Assert.Contains(profile.Vehicles, v => v.Type == VehicleType.Refrigerated && v.PlateNumber is null);
        Assert.Equal([1, 33], profile.ServiceCities.Select(c => c.CityId).Order());
    }

    [Fact]
    public async Task An_email_already_registered_is_a_conflict_whatever_the_letter_case_or_user_type()
    {
        var (db, time) = await NewDatabaseAsync();
        await using (var scope = NewScope(db, time))
            await scope.ServiceProvider.GetRequiredService<IAccountService>().RegisterShipperAsync(Shipper("ali@x.com"));

        await using var second = NewScope(db, time);
        var accounts = second.ServiceProvider.GetRequiredService<IAccountService>();

        var sameType = await Assert.ThrowsAsync<ConflictException>(() => accounts.RegisterShipperAsync(Shipper("ALI@X.COM", "+905000000001")));
        Assert.Equal("Bu e-posta adresiyle zaten bir hesap var.", sameType.Message);

        await using var third = NewScope(db, time);
        await Assert.ThrowsAsync<ConflictException>(
            () => third.ServiceProvider.GetRequiredService<IAccountService>().RegisterCarrierAsync(Carrier("Ali@x.com", "+905000000002")));
    }

    [Fact]
    public async Task A_phone_already_registered_is_a_conflict()
    {
        var (db, time) = await NewDatabaseAsync();
        await using (var scope = NewScope(db, time))
            await scope.ServiceProvider.GetRequiredService<IAccountService>().RegisterShipperAsync(Shipper("ali@x.com", "+905321234567"));

        await using var second = NewScope(db, time);
        var error = await Assert.ThrowsAsync<ConflictException>(
            () => second.ServiceProvider.GetRequiredService<IAccountService>().RegisterCarrierAsync(Carrier("veli@x.com", "+905321234567")));

        Assert.Equal("Bu telefon numarasıyla zaten bir hesap var.", error.Message);
    }

    [Fact]
    public async Task A_conflict_leaves_nothing_behind()
    {
        var (db, time) = await NewDatabaseAsync();
        await using (var scope = NewScope(db, time))
            await scope.ServiceProvider.GetRequiredService<IAccountService>().RegisterShipperAsync(Shipper("ali@x.com", "+905321234567"));

        await using (var second = NewScope(db, time))
            await Assert.ThrowsAsync<ConflictException>(
                () => second.ServiceProvider.GetRequiredService<IAccountService>().RegisterCarrierAsync(Carrier("veli@x.com", "+905321234567")));

        await using var read = db.NewContext();
        Assert.Equal(1, await read.Users.CountAsync());
        Assert.Equal(0, await read.CarrierProfiles.CountAsync());
        Assert.Equal(0, await read.Vehicles.CountAsync());
    }

    [Fact]
    public async Task Registration_is_all_or_nothing_a_failure_in_the_last_step_removes_the_user_too()
    {
        var (db, time) = await NewDatabaseAsync();

        // Doğrulayıcı atlatılsa bile veritabanı geçersiz çalışma ilini (999) reddeder; yarım hesap kalmamalı.
        await using (var scope = NewScope(db, time))
            await Assert.ThrowsAsync<DbUpdateException>(
                () => scope.ServiceProvider.GetRequiredService<IAccountService>().RegisterCarrierAsync(Carrier(serviceCities: [33, 999])));

        await using var read = db.NewContext();
        Assert.Equal(0, await read.Users.CountAsync());
        Assert.Equal(0, await read.CarrierProfiles.CountAsync());
        Assert.Equal(0, await read.Vehicles.CountAsync());
        Assert.Equal(0, await read.Set<IdentityUserRole<Guid>>().CountAsync());
    }

    [Fact]
    public async Task Identity_rejects_a_weak_password_even_if_validation_is_bypassed()
    {
        var (db, time) = await NewDatabaseAsync();
        await using var scope = NewScope(db, time);

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => scope.ServiceProvider.GetRequiredService<IAccountService>().RegisterShipperAsync(Shipper() with { Password = "abc" }));

        await using var read = db.NewContext();
        Assert.Equal(0, await read.Users.CountAsync());
    }

    [Fact]
    public async Task Five_wrong_attempts_lock_the_account_for_15_minutes_by_configuration()
    {
        var (db, time) = await NewDatabaseAsync();
        await using var scope = NewScope(db, time);
        var options = scope.ServiceProvider.GetRequiredService<Microsoft.Extensions.Options.IOptions<IdentityOptions>>().Value;

        Assert.True(options.Lockout.AllowedForNewUsers);
        Assert.Equal(5, options.Lockout.MaxFailedAccessAttempts);
        Assert.Equal(TimeSpan.FromMinutes(15), options.Lockout.DefaultLockoutTimeSpan);
        Assert.Equal(8, options.Password.RequiredLength);
        Assert.True(options.User.RequireUniqueEmail);
    }

    [Fact]
    public async Task Five_simultaneous_registrations_with_the_same_email_create_exactly_one_account()
    {
        var (db, time) = await NewDatabaseAsync();

        var attempts = Enumerable.Range(0, 5).Select(async i =>
        {
            await using var scope = NewScope(db, time);
            try
            {
                await scope.ServiceProvider.GetRequiredService<IAccountService>()
                    .RegisterShipperAsync(Shipper("ayni@x.com", $"+90500000000{i}"));
                return (Exception?)null;
            }
            catch (Exception exception)
            {
                return exception;
            }
        });
        var results = await Task.WhenAll(attempts);

        Assert.Equal(1, results.Count(e => e is null));
        Assert.All(results.Where(e => e is not null), e => Assert.IsType<ConflictException>(e));
        await using var read = db.NewContext();
        Assert.Equal(1, await read.Users.CountAsync());
        Assert.Equal(1, await read.ShipperProfiles.CountAsync());
    }
}
