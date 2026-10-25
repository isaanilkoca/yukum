using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Data.SqlClient;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Accounts;
using Yukum.Application.Common;
using Yukum.Domain.Accounts;
using Yukum.Infrastructure.Persistence;

namespace Yukum.Infrastructure.Identity;

/// <summary>
/// <see cref="IAccountService"/>'in ASP.NET Core Identity ile gerçeği. Kullanıcı, rol, profil, araç ve çalışma illerini
/// tek veritabanı işleminde (transaction) oluşturur: herhangi bir adım başarısız olursa hiçbiri kaydedilmez.
/// </summary>
public sealed class AccountService(AppDbContext context, UserManager<AppUser> users, TimeProvider time) : IAccountService
{
    private const string EmailTakenMessage = "Bu e-posta adresiyle zaten bir hesap var.";
    private const string PhoneTakenMessage = "Bu telefon numarasıyla zaten bir hesap var.";

    // SQL Server'ın "benzersiz indeks ihlali" hata numaraları.
    private const int UniqueIndexViolation = 2601;
    private const int UniqueConstraintViolation = 2627;

    /// <inheritdoc />
    public Task<RegisteredUserDto> RegisterShipperAsync(RegisterShipperCommand command, CancellationToken cancellationToken = default) =>
        CreateAsync(UserType.Shipper, RoleNames.Shipper, command.FullName!, command.Email!, command.Phone!, command.Password!,
            user => context.ShipperProfiles.Add(new ShipperProfile
            {
                UserId = user.Id,
                CompanyName = command.CompanyName,
                TaxNumber = command.TaxNumber,
                TaxOffice = command.TaxOffice,
                CityId = command.CityId!.Value
            }),
            cancellationToken);

    /// <inheritdoc />
    public Task<RegisteredUserDto> RegisterCarrierAsync(RegisterCarrierCommand command, CancellationToken cancellationToken = default) =>
        CreateAsync(UserType.Carrier, RoleNames.Carrier, command.FullName!, command.Email!, command.Phone!, command.Password!,
            user =>
            {
                context.CarrierProfiles.Add(new CarrierProfile { UserId = user.Id, HomeCityId = command.HomeCityId!.Value });

                context.Vehicles.AddRange(command.Vehicles!.Select(v => new Vehicle
                {
                    CarrierId = user.Id,
                    Type = v.Type!.Value,
                    PlateNumber = v.PlateNumber,
                    CapacityKg = v.CapacityKg!.Value,
                    CapacityVolume = v.CapacityVolume
                }));

                context.CarrierServiceCities.AddRange((command.ServiceCityIds ?? [])
                    .Select(cityId => new CarrierServiceCity { CarrierId = user.Id, CityId = cityId }));
            },
            cancellationToken);

    /// <summary>Ortak akış: kullanıcıyı oluştur, rolü ver, profili ekle, hepsini tek işlemde kaydet.</summary>
    private async Task<RegisteredUserDto> CreateAsync(
        UserType type, string role, string fullName, string email, string phone, string password,
        Action<AppUser> addProfile, CancellationToken cancellationToken)
    {
        // using: commit edilmeden çıkılırsa (hata, çakışma) işlem otomatik geri alınır.
        await using var transaction = await context.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            if (await context.Users.AnyAsync(u => u.PhoneNumber == phone, cancellationToken))
                throw new ConflictException(PhoneTakenMessage);

            var user = new AppUser
            {
                UserName = email,
                Email = email,
                PhoneNumber = phone,
                FullName = fullName,
                UserType = type,
                IsActive = true,
                KvkkAcceptedAt = time.GetUtcNow().UtcDateTime
            };

            var created = await users.CreateAsync(user, password);
            if (!created.Succeeded)
                throw MapFailure(created);

            var inRole = await users.AddToRoleAsync(user, role);
            if (!inRole.Succeeded)
                throw MapFailure(inRole);

            addProfile(user);
            await context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return new RegisteredUserDto(user.Id, user.FullName, user.Email!, user.UserType);
        }
        catch (DbUpdateException exception) when (exception.GetBaseException() is SqlException { Number: UniqueIndexViolation or UniqueConstraintViolation } sql)
        {
            // İki istek aynı anda aynı e-posta/telefonla gelirse ön kontrolü ikisi de geçer; veritabanının benzersiz
            // indeksi ikincisini reddeder. Bunu da kullanıcıya "zaten kayıtlı" olarak söyleriz.
            throw new ConflictException(sql.Message.Contains("PhoneNumber", StringComparison.OrdinalIgnoreCase) ? PhoneTakenMessage : EmailTakenMessage);
        }
    }

    /// <summary>Identity hatasını çevirir: kopya e-posta çakışmadır; diğerleri doğrulamadan geçmiş istekte beklenmez.</summary>
    private static Exception MapFailure(IdentityResult result)
    {
        if (result.Errors.Any(e => e.Code is "DuplicateEmail" or "DuplicateUserName"))
            return new ConflictException(EmailTakenMessage);

        return new InvalidOperationException("Hesap oluşturulamadı: " + string.Join(", ", result.Errors.Select(e => e.Code)));
    }
}
