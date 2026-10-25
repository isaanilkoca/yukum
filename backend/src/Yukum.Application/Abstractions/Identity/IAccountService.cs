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
}
