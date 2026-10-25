using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Time.Testing;
using Yukum.Domain.Accounts;
using Yukum.Infrastructure.Identity;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Data;

// Aşama D1: kullanıcı, roller, profiller, araçlar ve yenileme jetonları tabloları. Kurallar veritabanı düzeyinde kanıtlanır.
[Collection("SqlServer")]
public class AccountsTests(SqlServerFixture sql)
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 25, 9, 0, 0, TimeSpan.Zero);

    private static AppUser NewUser(string email, string? phone = null, UserType type = UserType.Shipper) => new()
    {
        UserName = email,
        NormalizedUserName = email.ToUpperInvariant(),
        Email = email,
        NormalizedEmail = email.ToUpperInvariant(),
        PhoneNumber = phone,
        FullName = "Test Kullanıcı",
        UserType = type,
        KvkkAcceptedAt = T0.UtcDateTime
    };

    private async Task<(TestDatabase Db, FakeTimeProvider Time)> NewDatabaseAsync()
    {
        var time = new FakeTimeProvider(T0);
        return (await sql.CreateDatabaseAsync(time), time);
    }

    private static async Task<Guid> AddCarrierAsync(TestDatabase db, string email = "t@x.com")
    {
        await using var context = db.NewContext();
        var user = NewUser(email, null, UserType.Carrier);
        context.Set<AppUser>().Add(user);
        context.Set<CarrierProfile>().Add(new CarrierProfile { UserId = user.Id, HomeCityId = 33 });
        await context.SaveChangesAsync();
        return user.Id;
    }

    // ---------- tablolar ve roller ----------
    [Fact]
    public async Task Tables_use_the_names_from_the_report()
    {
        var (db, _) = await NewDatabaseAsync();
        await using var context = db.NewContext();

        var tables = await context.Database.SqlQueryRaw<string>("SELECT name AS Value FROM sys.tables").ToListAsync();

        foreach (var expected in new[] { "Users", "Roles", "UserRoles", "ShipperProfiles", "CarrierProfiles", "Vehicles", "CarrierServiceCities", "RefreshTokens" })
            Assert.Contains(expected, tables);
        Assert.DoesNotContain("AspNetUsers", tables);
    }

    [Fact]
    public async Task Roles_Admin_Shipper_and_Carrier_are_seeded()
    {
        var (db, _) = await NewDatabaseAsync();
        await using var context = db.NewContext();

        var roles = await context.Set<IdentityRole<Guid>>().OrderBy(r => r.Name).ToListAsync();

        Assert.Equal(["Admin", "Carrier", "Shipper"], roles.Select(r => r.Name));
        Assert.Equal(["ADMIN", "CARRIER", "SHIPPER"], roles.Select(r => r.NormalizedName));
        Assert.Equal(RoleNames.Admin, roles[0].Name);
        Assert.Equal(RoleNames.Carrier, roles[1].Name);
        Assert.Equal(RoleNames.Shipper, roles[2].Name);
    }

    // ---------- kullanıcı ----------
    [Fact]
    public async Task User_gets_a_guid_id_CreatedAt_and_no_UpdatedAt_on_add()
    {
        var (db, _) = await NewDatabaseAsync();
        await using (var context = db.NewContext())
        {
            context.Set<AppUser>().Add(NewUser("ali@x.com", "+905551112233"));
            await context.SaveChangesAsync();
        }

        await using var read = db.NewContext();
        var user = await read.Set<AppUser>().SingleAsync();
        Assert.NotEqual(Guid.Empty, user.Id);
        Assert.Equal(T0.UtcDateTime, user.CreatedAt);
        Assert.Null(user.UpdatedAt);
        Assert.True(user.IsActive);
        Assert.False(user.IsBlocked);
        Assert.Equal(T0.UtcDateTime, user.KvkkAcceptedAt);
    }

    [Fact]
    public async Task User_update_sets_UpdatedAt_and_keeps_CreatedAt()
    {
        var (db, time) = await NewDatabaseAsync();
        await using (var context = db.NewContext())
        {
            context.Set<AppUser>().Add(NewUser("ali@x.com"));
            await context.SaveChangesAsync();
        }

        time.Advance(TimeSpan.FromHours(3));
        await using (var context = db.NewContext())
        {
            (await context.Set<AppUser>().SingleAsync()).FullName = "Yeni Ad";
            await context.SaveChangesAsync();
        }

        await using var read = db.NewContext();
        var user = await read.Set<AppUser>().SingleAsync();
        Assert.Equal(T0.UtcDateTime, user.CreatedAt);
        Assert.Equal(T0.AddHours(3).UtcDateTime, user.UpdatedAt);
    }

    [Fact]
    public async Task UserType_is_stored_as_a_number()
    {
        var (db, _) = await NewDatabaseAsync();
        await using var context = db.NewContext();
        context.Set<AppUser>().Add(NewUser("c@x.com", null, UserType.Carrier));
        await context.SaveChangesAsync();

        var stored = await context.Database.SqlQueryRaw<int>("SELECT CAST(UserType AS int) AS Value FROM Users").SingleAsync();

        Assert.Equal(2, stored);
    }

    [Fact]
    public async Task Two_users_cannot_share_an_email_whatever_the_letter_case()
    {
        var (db, _) = await NewDatabaseAsync();
        await using (var context = db.NewContext())
        {
            context.Set<AppUser>().Add(NewUser("ali@x.com"));
            await context.SaveChangesAsync();
        }

        await using var second = db.NewContext();
        var duplicate = NewUser("ali@x.com");
        duplicate.UserName = "baska-kullanici-adi";
        duplicate.NormalizedUserName = "BASKA-KULLANICI-ADI";
        second.Set<AppUser>().Add(duplicate);

        await Assert.ThrowsAsync<DbUpdateException>(() => second.SaveChangesAsync());
    }

    [Fact]
    public async Task Two_users_cannot_share_a_phone_number()
    {
        var (db, _) = await NewDatabaseAsync();
        await using (var context = db.NewContext())
        {
            context.Set<AppUser>().Add(NewUser("ali@x.com", "+905551112233"));
            await context.SaveChangesAsync();
        }

        await using var second = db.NewContext();
        second.Set<AppUser>().Add(NewUser("veli@x.com", "+905551112233"));

        await Assert.ThrowsAsync<DbUpdateException>(() => second.SaveChangesAsync());
    }

    [Fact]
    public async Task Several_users_without_a_phone_number_are_allowed()
    {
        var (db, _) = await NewDatabaseAsync();
        await using var context = db.NewContext();
        context.Set<AppUser>().AddRange(NewUser("a@x.com"), NewUser("b@x.com"), NewUser("c@x.com"));

        await context.SaveChangesAsync();

        Assert.Equal(3, await context.Set<AppUser>().CountAsync());
    }

    [Fact]
    public async Task A_user_can_hold_a_role()
    {
        var (db, _) = await NewDatabaseAsync();
        await using var context = db.NewContext();
        var user = NewUser("ali@x.com");
        context.Set<AppUser>().Add(user);
        var shipperRole = await context.Set<IdentityRole<Guid>>().SingleAsync(r => r.Name == RoleNames.Shipper);
        context.Set<IdentityUserRole<Guid>>().Add(new IdentityUserRole<Guid> { UserId = user.Id, RoleId = shipperRole.Id });

        await context.SaveChangesAsync();

        Assert.Equal(1, await context.Set<IdentityUserRole<Guid>>().CountAsync(r => r.UserId == user.Id));
    }

    // ---------- Yük Veren profili ----------
    [Fact]
    public async Task Shipper_profile_is_saved_and_linked_to_user_and_city()
    {
        var (db, _) = await NewDatabaseAsync();
        Guid userId;
        await using (var context = db.NewContext())
        {
            var user = NewUser("ali@x.com");
            context.Set<AppUser>().Add(user);
            context.Set<ShipperProfile>().Add(new ShipperProfile
            {
                UserId = user.Id, CompanyName = "Ali Tarım", TaxNumber = "1234567890", TaxOffice = "Mersin", About = "Tarım ilacı", CityId = 33
            });
            await context.SaveChangesAsync();
            userId = user.Id;
        }

        await using var read = db.NewContext();
        var profile = await read.Set<ShipperProfile>().SingleAsync(p => p.UserId == userId);
        Assert.Equal("Ali Tarım", profile.CompanyName);
        Assert.Equal(33, profile.CityId);
    }

    [Fact]
    public async Task Shipper_profile_with_a_missing_city_is_rejected()
    {
        var (db, _) = await NewDatabaseAsync();
        await using var context = db.NewContext();
        var user = NewUser("ali@x.com");
        context.Set<AppUser>().Add(user);
        context.Set<ShipperProfile>().Add(new ShipperProfile { UserId = user.Id, CityId = 999 });

        await Assert.ThrowsAsync<DbUpdateException>(() => context.SaveChangesAsync());
    }

    [Fact]
    public async Task Shipper_profile_without_a_user_is_rejected()
    {
        var (db, _) = await NewDatabaseAsync();
        await using var context = db.NewContext();
        context.Set<ShipperProfile>().Add(new ShipperProfile { UserId = Guid.NewGuid(), CityId = 33 });

        await Assert.ThrowsAsync<DbUpdateException>(() => context.SaveChangesAsync());
    }

    // ---------- Taşımacı profili, araçlar, çalışma bölgeleri ----------
    [Fact]
    public async Task Carrier_profile_has_sensible_defaults()
    {
        var (db, _) = await NewDatabaseAsync();
        var carrierId = await AddCarrierAsync(db);

        await using var read = db.NewContext();
        var profile = await read.Set<CarrierProfile>().SingleAsync(p => p.UserId == carrierId);

        Assert.Equal(0m, profile.AverageRating);
        Assert.Equal(0, profile.RatingCount);
        Assert.Equal(0, profile.CompletedJobCount);
        Assert.True(profile.IsAvailable);
        Assert.Equal(33, profile.HomeCityId);
    }

    [Fact]
    public async Task Carrier_keeps_its_vehicles_and_service_cities()
    {
        var (db, _) = await NewDatabaseAsync();
        var carrierId = await AddCarrierAsync(db);
        await using (var context = db.NewContext())
        {
            context.Set<Vehicle>().AddRange(
                new Vehicle { CarrierId = carrierId, Type = VehicleType.Truck, PlateNumber = "33 ABC 123", CapacityKg = 24000, CapacityVolume = 90m },
                new Vehicle { CarrierId = carrierId, Type = VehicleType.Refrigerated, CapacityKg = 8000 });
            context.Set<CarrierServiceCity>().AddRange(
                new CarrierServiceCity { CarrierId = carrierId, CityId = 33 },
                new CarrierServiceCity { CarrierId = carrierId, CityId = 1 });
            await context.SaveChangesAsync();
        }

        await using var read = db.NewContext();
        var profile = await read.Set<CarrierProfile>().Include(p => p.Vehicles).Include(p => p.ServiceCities).SingleAsync();
        Assert.Equal(2, profile.Vehicles.Count);
        Assert.Contains(profile.Vehicles, v => v.Type == VehicleType.Refrigerated && v.PlateNumber is null);
        Assert.Equal([1, 33], profile.ServiceCities.Select(c => c.CityId).Order());
    }

    [Fact]
    public async Task VehicleType_is_stored_as_a_number()
    {
        var (db, _) = await NewDatabaseAsync();
        var carrierId = await AddCarrierAsync(db);
        await using var context = db.NewContext();
        context.Set<Vehicle>().Add(new Vehicle { CarrierId = carrierId, Type = VehicleType.Other, CapacityKg = 1000 });
        await context.SaveChangesAsync();

        var stored = await context.Database.SqlQueryRaw<int>("SELECT CAST(VehicleType AS int) AS Value FROM Vehicles").SingleAsync();

        Assert.Equal(99, stored);
    }

    [Fact]
    public async Task A_removed_vehicle_is_soft_deleted_and_hidden()
    {
        var (db, _) = await NewDatabaseAsync();
        var carrierId = await AddCarrierAsync(db);
        await using (var context = db.NewContext())
        {
            context.Set<Vehicle>().Add(new Vehicle { CarrierId = carrierId, Type = VehicleType.Lorry, CapacityKg = 5000 });
            await context.SaveChangesAsync();
        }

        await using (var context = db.NewContext())
        {
            context.Set<Vehicle>().Remove(await context.Set<Vehicle>().SingleAsync());
            await context.SaveChangesAsync();
        }

        await using var read = db.NewContext();
        Assert.Equal(0, await read.Set<Vehicle>().CountAsync());
        Assert.True((await read.Set<Vehicle>().IgnoreQueryFilters().SingleAsync()).IsDeleted);
    }

    [Fact]
    public async Task Vehicle_of_a_missing_carrier_is_rejected()
    {
        var (db, _) = await NewDatabaseAsync();
        await using var context = db.NewContext();
        context.Set<Vehicle>().Add(new Vehicle { CarrierId = Guid.NewGuid(), Type = VehicleType.Truck, CapacityKg = 1 });

        await Assert.ThrowsAsync<DbUpdateException>(() => context.SaveChangesAsync());
    }

    [Fact]
    public async Task The_same_service_city_cannot_be_added_twice_and_the_city_must_exist()
    {
        var (db, _) = await NewDatabaseAsync();
        var carrierId = await AddCarrierAsync(db);
        await using (var context = db.NewContext())
        {
            context.Set<CarrierServiceCity>().Add(new CarrierServiceCity { CarrierId = carrierId, CityId = 33 });
            await context.SaveChangesAsync();
        }

        await using var duplicate = db.NewContext();
        duplicate.Set<CarrierServiceCity>().Add(new CarrierServiceCity { CarrierId = carrierId, CityId = 33 });
        await Assert.ThrowsAsync<DbUpdateException>(() => duplicate.SaveChangesAsync());

        await using var missing = db.NewContext();
        missing.Set<CarrierServiceCity>().Add(new CarrierServiceCity { CarrierId = carrierId, CityId = 999 });
        await Assert.ThrowsAsync<DbUpdateException>(() => missing.SaveChangesAsync());
    }

    [Fact]
    public async Task Carrier_profile_with_a_missing_home_city_is_rejected()
    {
        var (db, _) = await NewDatabaseAsync();
        await using var context = db.NewContext();
        var user = NewUser("c@x.com", null, UserType.Carrier);
        context.Set<AppUser>().Add(user);
        context.Set<CarrierProfile>().Add(new CarrierProfile { UserId = user.Id, HomeCityId = 999 });

        await Assert.ThrowsAsync<DbUpdateException>(() => context.SaveChangesAsync());
    }

    // ---------- yenileme jetonları ----------
    private static RefreshToken NewToken(Guid userId, string hash, TimeSpan lifetime) => new()
    {
        UserId = userId,
        TokenHash = hash,
        DeviceId = "device-1",
        ExpiresAt = T0.UtcDateTime + lifetime
    };

    [Fact]
    public async Task Refresh_token_is_saved_with_its_rotation_columns()
    {
        var (db, _) = await NewDatabaseAsync();
        var userId = await AddCarrierAsync(db);
        Guid firstId;
        await using (var context = db.NewContext())
        {
            var first = NewToken(userId, "hash-1", TimeSpan.FromDays(30));
            var second = NewToken(userId, "hash-2", TimeSpan.FromDays(30));
            context.Set<RefreshToken>().AddRange(first, second);
            await context.SaveChangesAsync();

            first.RevokedAt = T0.UtcDateTime;
            first.ReplacedByTokenId = second.Id;
            await context.SaveChangesAsync();
            firstId = first.Id;
        }

        await using var read = db.NewContext();
        var saved = await read.Set<RefreshToken>().SingleAsync(t => t.Id == firstId);
        Assert.Equal("hash-1", saved.TokenHash);
        Assert.Equal("device-1", saved.DeviceId);
        Assert.Equal(T0.UtcDateTime, saved.RevokedAt);
        Assert.NotNull(saved.ReplacedByTokenId);
        Assert.Equal(T0.AddDays(30).UtcDateTime, saved.ExpiresAt);
    }

    [Fact]
    public async Task Refresh_token_hash_must_be_unique()
    {
        var (db, _) = await NewDatabaseAsync();
        var userId = await AddCarrierAsync(db);
        await using (var context = db.NewContext())
        {
            context.Set<RefreshToken>().Add(NewToken(userId, "ayni-hash", TimeSpan.FromDays(30)));
            await context.SaveChangesAsync();
        }

        await using var second = db.NewContext();
        second.Set<RefreshToken>().Add(NewToken(userId, "ayni-hash", TimeSpan.FromDays(30)));

        await Assert.ThrowsAsync<DbUpdateException>(() => second.SaveChangesAsync());
    }

    [Fact]
    public async Task Two_simultaneous_updates_of_the_same_refresh_token_are_detected()
    {
        var (db, _) = await NewDatabaseAsync();
        var userId = await AddCarrierAsync(db);
        await using (var context = db.NewContext())
        {
            context.Set<RefreshToken>().Add(NewToken(userId, "hash-1", TimeSpan.FromDays(30)));
            await context.SaveChangesAsync();
        }

        await using var first = db.NewContext();
        await using var second = db.NewContext();
        var tokenFirst = await first.Set<RefreshToken>().SingleAsync();
        var tokenSecond = await second.Set<RefreshToken>().SingleAsync();

        tokenFirst.RevokedAt = T0.UtcDateTime;
        await first.SaveChangesAsync();

        tokenSecond.RevokedAt = T0.UtcDateTime;
        await Assert.ThrowsAsync<DbUpdateConcurrencyException>(() => second.SaveChangesAsync());
    }

    [Fact]
    public async Task Refresh_token_of_a_missing_user_is_rejected()
    {
        var (db, _) = await NewDatabaseAsync();
        await using var context = db.NewContext();
        context.Set<RefreshToken>().Add(NewToken(Guid.NewGuid(), "hash-x", TimeSpan.FromDays(30)));

        await Assert.ThrowsAsync<DbUpdateException>(() => context.SaveChangesAsync());
    }

    // ---------- hesap silme ----------
    [Fact]
    public async Task Deleting_a_user_removes_the_profile_vehicles_service_cities_and_tokens()
    {
        var (db, _) = await NewDatabaseAsync();
        var carrierId = await AddCarrierAsync(db);
        await using (var context = db.NewContext())
        {
            context.Set<Vehicle>().Add(new Vehicle { CarrierId = carrierId, Type = VehicleType.Truck, CapacityKg = 1 });
            context.Set<CarrierServiceCity>().Add(new CarrierServiceCity { CarrierId = carrierId, CityId = 33 });
            context.Set<RefreshToken>().Add(NewToken(carrierId, "hash-1", TimeSpan.FromDays(30)));
            await context.SaveChangesAsync();
        }

        await using (var context = db.NewContext())
        {
            context.Set<AppUser>().Remove(await context.Set<AppUser>().SingleAsync());
            await context.SaveChangesAsync();
        }

        await using var read = db.NewContext();
        Assert.Equal(0, await read.Set<AppUser>().CountAsync());
        Assert.Equal(0, await read.Set<CarrierProfile>().CountAsync());
        Assert.Equal(0, await read.Set<Vehicle>().IgnoreQueryFilters().CountAsync());
        Assert.Equal(0, await read.Set<CarrierServiceCity>().CountAsync());
        Assert.Equal(0, await read.Set<RefreshToken>().IgnoreQueryFilters().CountAsync());
    }
}
