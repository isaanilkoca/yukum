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

/// <summary>Giriş isteği. Alanlar "boş olabilir" (<c>?</c>) tanımlıdır ki eksik alan bizim Türkçe doğrulama mesajımızla reddedilsin.</summary>
/// <param name="EmailOrPhone">E-posta ya da cep telefonu (telefon "0532 123 45 67", "+90 532…" gibi yazılabilir).</param>
/// <param name="Password">Şifre.</param>
/// <param name="DeviceId">Cihazın kimliği (iOS'ta kalıcı bir UUID). Oturum jetonları cihaz bazında yönetilir (D4).</param>
/// <param name="DeviceName">Cihazın adı (opsiyonel, örn. "Anıl'ın iPhone'u").</param>
public sealed record LoginCommand(string? EmailOrPhone, string? Password, string? DeviceId, string? DeviceName);

/// <summary>Giriş yapmış kullanıcının istemciye gösterilen özeti.</summary>
/// <param name="Id">Kullanıcı numarası.</param>
/// <param name="DisplayName">Ekranda görünen ad (ad-soyad ya da firma adı).</param>
/// <param name="Role">Rol: <c>Shipper</c>, <c>Carrier</c> ya da <c>Admin</c>. İstemci ana ekranı buna göre seçer.</param>
/// <param name="AvatarUrl">Profil fotoğrafı adresi (yoksa boş).</param>
public sealed record AuthUserDto(Guid Id, string DisplayName, string Role, string? AvatarUrl);

/// <summary>Başarılı giriş cevabı.</summary>
/// <param name="AccessToken">Kısa ömürlü erişim jetonu (JWT).</param>
/// <param name="AccessTokenExpiresAt">Erişim jetonunun bitiş zamanı (UTC).</param>
/// <param name="User">Kullanıcı özeti.</param>
public sealed record LoginResponse(string AccessToken, DateTime AccessTokenExpiresAt, AuthUserDto User);
