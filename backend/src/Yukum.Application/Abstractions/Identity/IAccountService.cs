using Yukum.Application.Accounts;

namespace Yukum.Application.Abstractions.Identity;

/// <summary>
/// Hesap oluşturma sözleşmesi. Gerçeği Infrastructure'dadır (ASP.NET Core Identity); iş kuralı kodu Identity'yi bilmez.
/// Gelen komutlar doğrulanmış ve normalleştirilmiştir (e-posta küçük harf, telefon +90 biçiminde).
/// </summary>
public interface IAccountService
{
    /// <summary>
    /// Yük Veren hesabını oluşturur: kullanıcı + Shipper rolü + profil, tek işlemde (biri başarısız olursa hiçbiri kaydedilmez).
    /// </summary>
    /// <exception cref="Common.ConflictException">E-posta ya da telefon zaten kayıtlı.</exception>
    Task<RegisteredUserDto> RegisterShipperAsync(RegisterShipperCommand command, CancellationToken cancellationToken = default);

    /// <summary>
    /// Taşımacı hesabını oluşturur: kullanıcı + Carrier rolü + profil + araçlar + çalışma illeri, tek işlemde.
    /// </summary>
    /// <exception cref="Common.ConflictException">E-posta ya da telefon zaten kayıtlı.</exception>
    Task<RegisteredUserDto> RegisterCarrierAsync(RegisterCarrierCommand command, CancellationToken cancellationToken = default);

    /// <summary>Verilen şifre bu kullanıcınınki mi? (Kilit sayacını artırmaz; hesap silme onayı için.)</summary>
    Task<bool> VerifyPasswordAsync(Guid userId, string password, CancellationToken cancellationToken = default);

    /// <summary>
    /// Hesabı anonimleştirir (kayıt silinmez): ad, e-posta, telefon, şifre, profil ve araç plakaları temizlenir, hesap pasifleşir,
    /// tüm oturumlar (yenileme jetonları) kapatılır. Aynı e-posta/telefon yeniden kullanılabilir hâle gelir.
    /// </summary>
    Task AnonymizeAsync(Guid userId, CancellationToken cancellationToken = default);

    // ─── Hesap Bilgilerim (15 Kasım): çağıran Application/Accounts/AccountProfileHandlers.cs ───

    /// <summary>Kullanıcı + rol profilini tek nesnede okur (AspNetUsers + ShipperProfiles/CarrierProfiles).</summary>
    /// <exception cref="Common.NotFoundException">Hesap yok ya da silinmiş.</exception>
    Task<AccountProfileDto> GetProfileAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Ad, telefon ve rol profil alanlarını yazar (doğrulanmış, kırpılmış, telefon +90 biçiminde gelir; CurrentPassword kullanılmaz).
    /// E-posta değişmez. Rolün kullanmadığı alanlar yok sayılır.
    /// </summary>
    /// <exception cref="Common.ConflictException">Telefon aynı rolde başka hesapta kayıtlı.</exception>
    Task UpdateProfileAsync(Guid userId, UpdateAccountProfileRequest values, CancellationToken cancellationToken = default);

    /// <summary>AvatarUrl'i yazar (null = kaldır), ESKİ değeri döner (eski dosyayı silmek için).</summary>
    Task<string?> SetAvatarAsync(Guid userId, string? avatarUrl, CancellationToken cancellationToken = default);

    /// <summary>Yük Veren'in herkese açık alanları (15 Kasım, 8. adım). Yük Veren değilse ya da silinmişse null. Telefon/e-posta/vergi bilgisi DÖNMEZ.</summary>
    Task<ShipperPublicInfo?> GetShipperPublicAsync(Guid shipperId, CancellationToken cancellationToken = default);
}

/// <summary>Yük Veren profilinin kimlik kısmı (sayılar handler'da ilan tablosundan hesaplanır).</summary>
public sealed record ShipperPublicInfo(Guid Id, string FullName, string? AvatarUrl, string? CompanyName, int? CityId, string? About, DateTime CreatedAt);
