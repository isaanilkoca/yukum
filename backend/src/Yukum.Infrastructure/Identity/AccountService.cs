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
    // Kullanıcıya gösterilen çakışma mesajları tek yerde.
    private const string EmailTakenMessage = "Bu e-posta adresiyle zaten bir hesap var.";
    private const string PhoneTakenMessage = "Bu telefon numarasıyla zaten bir hesap var.";

    // SQL Server'ın "benzersiz indeks ihlali" hata numaraları.
    private const int UniqueIndexViolation = 2601;
    private const int UniqueConstraintViolation = 2627;

    /// <inheritdoc />
    public Task<RegisteredUserDto> RegisterShipperAsync(RegisterShipperCommand command, CancellationToken cancellationToken = default) =>
        // Ortak akışı (CreateAsync) çağırır; yalnız 'profil nasıl eklenir' kısmı farklıdır (sondaki lambda: user => ...).
        CreateAsync(UserType.Shipper, RoleNames.Shipper, command.FullName!, command.Email!, command.Phone!, command.Password!,
            // Kullanıcı oluşturulunca Yük Veren profilini ekle (henüz kaydedilmedi).
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
                // Taşımacı profili.
                context.CarrierProfiles.Add(new CarrierProfile { UserId = user.Id, HomeCityId = command.HomeCityId!.Value });

                // Her araç için bir satır.
                context.Vehicles.AddRange(command.Vehicles!.Select(v => new Vehicle
                {
                    CarrierId = user.Id,
                    Type = v.Type!.Value,
                    PlateNumber = v.PlateNumber,
                    CapacityKg = v.CapacityKg!.Value,
                    CapacityVolume = v.CapacityVolume
                }));

                // Çalıştığı iller (opsiyonel; null ise boş liste).
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
            // Telefon önceden kayıtlı mı? (E-posta kontrolünü Identity kendisi yapar.)
            if (await context.Users.AnyAsync(u => u.PhoneNumber == phone, cancellationToken))
                throw new ConflictException(PhoneTakenMessage);

            // Yeni kullanıcı nesnesi. Giriş adı (UserName) e-postanın kendisidir.
            var user = new AppUser
            {
                UserName = email,
                Email = email,
                PhoneNumber = phone,
                FullName = fullName,
                UserType = type,
                IsActive = true,
                // KVKK onay anı kanıt olarak saklanır.
                KvkkAcceptedAt = time.GetUtcNow().UtcDateTime
            };

            // Identity: şifreyi hash'ler (PBKDF2), kuralları (şifre politikası, benzersiz e-posta) denetler, kullanıcıyı kaydeder. Şifre hiçbir zaman açık saklanmaz.
            var created = await users.CreateAsync(user, password);
            // Başarısızsa hata türüne göre çevir (kopya e-posta → 409).
            if (!created.Succeeded)
                throw MapFailure(created);

            // Kullanıcıya rolü ver (Shipper ya da Carrier). Rol uç adresinden gelir, istemciden değil.
            var inRole = await users.AddToRoleAsync(user, role);
            if (!inRole.Succeeded)
                throw MapFailure(inRole);

            // Profil/araç/bölge satırları eklenir (henüz kaydedilmedi).
            addProfile(user);
            // Bekleyen satırlar veritabanına yazılır.
            await context.SaveChangesAsync(cancellationToken);
            // Hepsi başarılıysa işlem ONAYLANIR. Buna gelmeden hata olursa hiçbir şey kalıcı olmaz (otomatik geri alınır).
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
        // Identity'nin kopya e-posta / kopya kullanıcı adı hata kodları → bizim 409 hatamız.
        if (result.Errors.Any(e => e.Code is "DuplicateEmail" or "DuplicateUserName"))
            return new ConflictException(EmailTakenMessage);

        return new InvalidOperationException("Hesap oluşturulamadı: " + string.Join(", ", result.Errors.Select(e => e.Code)));
    }
}
