using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Domain.Listings;

namespace Yukum.Application.Reviews;

// ┌─ BAĞLANTI HARİTASI: GetShipperProfileHandler.cs (15 Kasım, 8. adım) ─────────
// │ GELEN : Api/Controllers/ReviewsController.cs → GET /api/v1/shippers/{shipperId} ([Authorize]: giriş yapmış herkes)
// │ GİDEN : IAccountService.GetShipperPublicAsync → AspNetUsers + ShipperProfiles (yalnız açık alanlar)
// │         IRepository<Listing>                  → Listings tablosu (tamamlanan / açık ilan SAYISI; COUNT sorgusu, satırlar okunmaz)
// │         IGeographyRepository                  → il adı (önbellekli)
// │ iOS   : Views/ShipperProfileView ← ListingDetailView (Taşımacı, "Yük Veren" satırına dokununca)
// └──────────────────────────────────────────────────────────────────────
// NEDEN sayılar: Taşımacı için güvenilirlik işareti ("12 ilanı tamamlanmış, 2023'ten beri üye"). Yük Veren puanlanmadığı için puan yok.

/// <summary>Yük Veren'in herkese açık profili. Yük Veren değilse ya da hesap silinmişse 404.</summary>
public sealed class GetShipperProfileHandler(
    IAccountService accounts, IRepository<Listing> listings, IGeographyRepository geography) : IQueryHandler<GetShipperProfileQuery, ShipperProfileDto>
{
    public async Task<ShipperProfileDto> HandleAsync(GetShipperProfileQuery query, CancellationToken cancellationToken = default)
    {
        var info = await accounts.GetShipperPublicAsync(query.ShipperId, cancellationToken) ?? throw new NotFoundException("Yük Veren bulunamadı.");
        var completed = await listings.CountAsync(l => l.ShipperId == query.ShipperId && l.Status == ListingStatus.Completed, cancellationToken);
        var open = await listings.CountAsync(l => l.ShipperId == query.ShipperId && l.Status == ListingStatus.Open, cancellationToken);
        var cityName = info.CityId is { } id ? (await geography.ListCitiesAsync(cancellationToken)).FirstOrDefault(c => c.Id == id)?.Name : null;
        return new ShipperProfileDto(info.Id, info.FullName, info.AvatarUrl, info.CompanyName, cityName, info.About, info.CreatedAt, completed, open);
    }
}
