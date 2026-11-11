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
}
