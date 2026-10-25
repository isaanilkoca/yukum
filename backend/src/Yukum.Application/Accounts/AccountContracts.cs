using Yukum.Domain.Accounts;

namespace Yukum.Application.Accounts;

/// <summary>Taşımacının kayıt sırasında girdiği bir araç.</summary>
/// <param name="Type">Araç tipi (Truck, Lorry, Pickup, Refrigerated, Other).</param>
/// <param name="PlateNumber">Plaka (opsiyonel).</param>
/// <param name="CapacityKg">Taşıma kapasitesi, kilogram.</param>
/// <param name="CapacityVolume">Hacim kapasitesi, metreküp (opsiyonel).</param>
public sealed record VehicleInput(VehicleType? Type, string? PlateNumber, int? CapacityKg, decimal? CapacityVolume);

/// <summary>
/// Yük Veren kayıt isteği. Alanlar "boş olabilir" (<c>?</c>) tanımlıdır ki eksik alan .NET'in İngilizce hatası yerine
/// bizim Türkçe doğrulama mesajımızla reddedilsin. Rol istemciden gelmez; bu uç Shipper rolünü kendisi verir.
/// </summary>
/// <param name="FullName">Ad-soyad ya da firma adı.</param>
/// <param name="Email">E-posta.</param>
/// <param name="Phone">Cep telefonu (0532…, +90 532… gibi biçimler kabul edilir).</param>
/// <param name="Password">Şifre.</param>
/// <param name="CityId">Bulunduğu ilin plaka kodu.</param>
/// <param name="CompanyName">Firma adı (opsiyonel).</param>
/// <param name="TaxNumber">Vergi numarası (opsiyonel, 10 veya 11 haneli).</param>
/// <param name="TaxOffice">Vergi dairesi (opsiyonel).</param>
/// <param name="KvkkAccepted">KVKK aydınlatma metni onaylandı mı? Zorunlu: true olmalı.</param>
public sealed record RegisterShipperCommand(
    string? FullName,
    string? Email,
    string? Phone,
    string? Password,
    int? CityId,
    string? CompanyName,
    string? TaxNumber,
    string? TaxOffice,
    bool KvkkAccepted);

/// <summary>Taşımacı kayıt isteği. En az bir araç zorunludur. Rol istemciden gelmez; bu uç Carrier rolünü kendisi verir.</summary>
/// <param name="FullName">Ad-soyad ya da firma adı.</param>
/// <param name="Email">E-posta.</param>
/// <param name="Phone">Cep telefonu.</param>
/// <param name="Password">Şifre.</param>
/// <param name="HomeCityId">Merkez ilinin plaka kodu.</param>
/// <param name="ServiceCityIds">Çalıştığı illerin plaka kodları (opsiyonel).</param>
/// <param name="Vehicles">Araçlar (en az 1).</param>
/// <param name="KvkkAccepted">KVKK aydınlatma metni onaylandı mı? Zorunlu: true olmalı.</param>
public sealed record RegisterCarrierCommand(
    string? FullName,
    string? Email,
    string? Phone,
    string? Password,
    int? HomeCityId,
    List<int>? ServiceCityIds,
    List<VehicleInput>? Vehicles,
    bool KvkkAccepted);

/// <summary>Kayıttan sonra istemciye dönen kullanıcı özeti. Şifre ve hash asla dönmez.</summary>
/// <param name="Id">Kullanıcı numarası.</param>
/// <param name="FullName">Ad-soyad ya da firma adı.</param>
/// <param name="Email">Normalleştirilmiş e-posta (küçük harf).</param>
/// <param name="UserType">Kullanıcı türü (Shipper veya Carrier).</param>
public sealed record RegisteredUserDto(Guid Id, string FullName, string Email, UserType UserType);
