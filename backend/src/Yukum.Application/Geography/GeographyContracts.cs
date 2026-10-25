namespace Yukum.Application.Geography;

/// <summary>İstemciye giden il bilgisi. <c>Id</c> plaka kodudur (karar K-013); koordinatlar istemciye gönderilmez.</summary>
/// <param name="Id">Plaka kodu (1–81).</param>
/// <param name="Name">İlin adı.</param>
public sealed record CityDto(int Id, string Name);

/// <summary>İstemciye giden ilçe bilgisi.</summary>
/// <param name="Id">İlçe numarası (1–973).</param>
/// <param name="Name">İlçenin adı.</param>
public sealed record DistrictDto(int Id, string Name);

/// <summary>Sorgu: tüm illeri getir.</summary>
public sealed record GetCitiesQuery;

/// <summary>Sorgu: bir ilin ilçelerini getir.</summary>
/// <param name="CityId">İlin plaka kodu.</param>
public sealed record GetDistrictsQuery(int CityId);
