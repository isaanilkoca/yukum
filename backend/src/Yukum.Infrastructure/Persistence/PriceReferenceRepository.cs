using Microsoft.EntityFrameworkCore;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Domain.Accounts;
using Yukum.Domain.Listings;

namespace Yukum.Infrastructure.Persistence;

/// <summary><see cref="IPriceReferenceRepository"/>'nin EF Core uygulaması: Offers + Listings birleştirilir, tek SQL'de süzülür.</summary>
public class PriceReferenceRepository(AppDbContext context) : IPriceReferenceRepository
{
    /// <inheritdoc />
    public async Task<IReadOnlyList<decimal>> ListCompletedAmountsAsync(
        int fromCityId, int toCityId, VehicleType vehicleType, DateTime since, int take, CancellationToken cancellationToken = default)
    {
        // SQL: SELECT TOP(@take) o.Amount FROM Offers o JOIN Listings l ON l.Id = o.ListingId
        //      WHERE o.Status = Completed AND o.DecidedAt >= @since AND l.FromCityId = .. AND l.ToCityId = .. AND l.VehicleType = ..
        //      ORDER BY o.DecidedAt DESC | yalnız tutar sütunu çekilir (AsNoTracking: izleme yok, hızlı)
        var amounts = from o in context.Offers.AsNoTracking()
                      join l in context.Listings.AsNoTracking() on o.ListingId equals l.Id
                      where o.Status == OfferStatus.Completed && o.DecidedAt >= since
                            && l.FromCityId == fromCityId && l.ToCityId == toCityId && l.VehicleType == vehicleType
                      orderby o.DecidedAt descending
                      select o.Amount;
        return await amounts.Take(take).ToListAsync(cancellationToken);
    }
}
