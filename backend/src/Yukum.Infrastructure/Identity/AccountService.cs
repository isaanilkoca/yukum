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
    public async Task<bool> VerifyPasswordAsync(Guid userId, string password, CancellationToken cancellationToken = default)
    {
        var user = await users.FindByIdAsync(userId.ToString());
        // CheckPasswordAsync: yalnız şifreyi karşılaştırır, hatalı deneme sayacını ve kilidi ETKİLEMEZ (giriş değil, onay)
        return user is not null && await users.CheckPasswordAsync(user, password);
    }

    /// <inheritdoc />
    public async Task AnonymizeAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var user = await users.FindByIdAsync(userId.ToString()) ?? throw new NotFoundException("Hesap bulunamadı.");
        var tag = userId.ToString("N");

        // Kullanıcı satırı silinmez (teklif/ilan/puan gibi kayıtlar ona bağlı); kişisel alanlar boşaltılır.
        // E-posta/kullanıcı adı numaraya göre benzersiz, ".invalid" uzantısı gerçek bir adres olamaz; böylece eski e-posta yeniden kayıt olabilir.
        user.FullName = "Silinmiş Kullanıcı";
        user.UserName = $"deleted-{tag}";
        user.Email = $"deleted-{tag}@deleted.invalid";
        user.PhoneNumber = null;
        user.PasswordHash = null;                         // şifre kalmadı: bu hesapla giriş artık mümkün değil
        user.AvatarUrl = null;
        user.IsActive = false;
        user.SecurityStamp = Guid.NewGuid().ToString();   // eski güvenlik damgası geçersiz olur
        var result = await users.UpdateAsync(user);       // normalize alanlar (NormalizedEmail vb.) UserManager tarafından güncellenir
        if (!result.Succeeded) throw new InvalidOperationException("Hesap anonimleştirilemedi: " + string.Join("; ", result.Errors.Select(e => e.Description)));

        // Profil ve araç bilgileri (ticari kimlik, plaka) temizlenir; puan sayıları karşı tarafın kaydı olduğu için kalır.
        await context.ShipperProfiles.Where(p => p.UserId == userId).ExecuteUpdateAsync(s => s
            .SetProperty(p => p.CompanyName, (string?)null).SetProperty(p => p.TaxNumber, (string?)null)
            .SetProperty(p => p.TaxOffice, (string?)null).SetProperty(p => p.About, (string?)null), cancellationToken);
        await context.CarrierProfiles.Where(p => p.UserId == userId).ExecuteUpdateAsync(s => s.SetProperty(p => p.About, (string?)null), cancellationToken);
        await context.Vehicles.Where(v => v.CarrierId == userId).ExecuteUpdateAsync(s => s.SetProperty(v => v.PlateNumber, (string?)null), cancellationToken);

        // Tüm cihazlardaki oturumlar kapanır: yenileme jetonları iptal edilir (erişim jetonu en geç 15 dk içinde zaten sona erer).
        var now = time.GetUtcNow().UtcDateTime;
        await context.RefreshTokens.Where(t => t.UserId == userId && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, now), cancellationToken);
    }

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
                CityId = command.CityId
            }),
            cancellationToken);

    /// <inheritdoc />
    public Task<RegisteredUserDto> RegisterCarrierAsync(RegisterCarrierCommand command, CancellationToken cancellationToken = default) =>
        CreateAsync(UserType.Carrier, RoleNames.Carrier, command.FullName!, command.Email!, command.Phone!, command.Password!,
            user =>
            {
                // Taşımacı profili.
                context.CarrierProfiles.Add(new CarrierProfile { UserId = user.Id, HomeCityId = command.HomeCityId });

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
            // E-posta ve telefon BU ROL için önceden kayıtlı mı? Başka rolde kayıtlı olması engel değildir (K-022: aynı kişi hem Yük Veren hem Taşımacı olabilir).
            var normalizedEmail = users.NormalizeEmail(email);
            if (await context.Users.AnyAsync(u => u.NormalizedEmail == normalizedEmail && u.UserType == type, cancellationToken))
                throw new ConflictException(EmailTakenMessage);
            if (await context.Users.AnyAsync(u => u.PhoneNumber == phone && u.UserType == type, cancellationToken))
                throw new ConflictException(PhoneTakenMessage);

            // Yeni kullanıcı nesnesi. Giriş adı (UserName) Identity'de TEK BAŞINA benzersiz olmak zorunda; aynı e-posta iki rolde
            // olabildiği için "e-posta_Rol" yapılır (örn. ali@x.com_Shipper). Kullanıcı bunu hiç görmez: giriş e-posta/telefon + rolle yapılır.
            var user = new AppUser
            {
                UserName = $"{email}_{type}",
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
