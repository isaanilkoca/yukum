using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Domain.Listings;

namespace Yukum.Application.Reviews;

/// <summary>Taşımacı profili: ortalama puan, tamamlanan iş sayısı ve son yorumlar (rota ve ilan başlığıyla).</summary>
public sealed class GetCarrierProfileHandler(
    ICarrierDirectory carriers,
    IRepository<Review> reviews,
    IRepository<Listing> listings,
    IUserDirectory users,
    IGeographyRepository geography,
    IRepository<Yukum.Domain.Accounts.Vehicle> vehicles) : IQueryHandler<GetCarrierProfileQuery, CarrierProfileDto>
{
    private const int MaxReviews = 20; // profilde en yeni 20 yorum (sayfalama gerekirse sonra)

    // FONKSİYON ROLÜ: API'NİN İŞ MANTIĞI | CarriersController çağırır: profil özeti + son yorumları derler
    /// <summary>Taşımacı yoksa 404.</summary>
    public async Task<CarrierProfileDto> HandleAsync(GetCarrierProfileQuery query, CancellationToken cancellationToken = default)
    {
        var summary = (await carriers.GetSummariesAsync([query.CarrierId], cancellationToken)).GetValueOrDefault(query.CarrierId)
            ?? throw new NotFoundException("Taşımacı bulunamadı.");

        // En yeni yorumlar: önce hepsi değil, ilk 20 (Take) | sıralama + sınır SQL'de (ORDER BY ... OFFSET/FETCH)
        var all = await reviews.ListAsync(r => r.CarrierId == query.CarrierId, asNoTracking: true, cancellationToken);
        var latest = all.OrderByDescending(r => r.CreatedAt).Take(MaxReviews).ToList();

        var listingMap = (await listings.ListAsync(l => latest.Select(r => r.ListingId).Contains(l.Id), asNoTracking: true, cancellationToken))
            .ToDictionary(l => l.Id);
        var names = await users.GetFullNamesAsync(latest.Select(r => r.ShipperId), cancellationToken);
        var cities = (await geography.ListCitiesAsync(cancellationToken)).ToDictionary(c => c.Id, c => c.Name);

        var items = latest.Where(r => listingMap.ContainsKey(r.ListingId)).Select(r =>
        {
            var l = listingMap[r.ListingId];
            return new ReviewItemDto(r.Rating, r.Comment, MaskName(names.GetValueOrDefault(r.ShipperId, "Yük Veren")),
                l.Title, cities[l.FromCityId], cities[l.ToCityId], r.CreatedAt);
        }).ToList();

        return new CarrierProfileDto(summary.UserId, summary.FullName, summary.About, summary.AverageRating,
            summary.RatingCount, summary.CompletedJobCount, items,
            summary.AvatarUrl, summary.HomeCityId is { } c ? cities.GetValueOrDefault(c) : null, summary.MemberSince,
            // Araçları (15 Kasım): Yük Veren aracın türünü/yaşını görüp karar verir; en yeni model üstte | plaka gönderilmez
            (await vehicles.ListAsync(v => v.CarrierId == query.CarrierId, asNoTracking: true, cancellationToken))
                .OrderByDescending(v => v.Year ?? 0).Select(v => new PublicVehicleDto(v.Type, v.Brand, v.Model, v.Year, v.CapacityKg)).ToList());
    }

    // Gizlilik: "Ali Veli" → "Ali V." (soyadın yalnız baş harfi) | tek kelimeyse olduğu gibi
    private static string MaskName(string fullName)
    {
        var parts = fullName.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        return parts.Length < 2 ? fullName : $"{parts[0]} {parts[^1][0]}.";
    }
}
