using Microsoft.EntityFrameworkCore;
using Yukum.Application.Abstractions.Identity;
using Yukum.Infrastructure.Persistence;

namespace Yukum.Infrastructure.Identity;

/// <summary><see cref="ICarrierDirectory"/> gerçekleştirmesi: CarrierProfiles + Users tablolarından okur, sayaçları günceller.</summary>
public class CarrierDirectory(AppDbContext context) : ICarrierDirectory
{
    /// <inheritdoc />
    public async Task<Dictionary<Guid, CarrierSummary>> GetSummariesAsync(IEnumerable<Guid> carrierIds, CancellationToken cancellationToken = default)
    {
        var ids = carrierIds.Distinct().ToList();
        // JOIN: Users (ad) + CarrierProfiles (puan) | SQL: SELECT ... FROM CarrierProfiles p JOIN Users u ON u.Id = p.UserId WHERE p.UserId IN (...)
        var rows = await (from p in context.CarrierProfiles.AsNoTracking()
                          join u in context.Users.AsNoTracking() on p.UserId equals u.Id
                          where ids.Contains(p.UserId)
                          select new CarrierSummary(p.UserId, u.FullName, p.About, p.AverageRating, p.RatingCount, p.CompletedJobCount, u.AvatarUrl, p.HomeCityId, u.CreatedAt))
            .ToListAsync(cancellationToken);
        return rows.ToDictionary(r => r.UserId);
    }

    /// <inheritdoc />
    public Task AddRatingAsync(Guid carrierId, int rating, CancellationToken cancellationToken = default) =>
        // ExecuteUpdate: SELECT yapmadan tek UPDATE gönderir. SQL'de SET'in sağ tarafı GÜNCELLEMEDEN ÖNCEKİ değerleri görür:
        // yeni ortalama = (eski ortalama x eski sayı + puan) / (eski sayı + 1). Eşzamanlı iki puan birbirini ezmez (okuyup-yazma yarışı yok).
        context.CarrierProfiles.Where(p => p.UserId == carrierId).ExecuteUpdateAsync(s => s
            .SetProperty(p => p.AverageRating, p => Math.Round((p.AverageRating * p.RatingCount + rating) / (p.RatingCount + 1), 2))
            .SetProperty(p => p.RatingCount, p => p.RatingCount + 1), cancellationToken);

    /// <inheritdoc />
    public Task AddCompletedJobAsync(Guid carrierId, CancellationToken cancellationToken = default) =>
        context.CarrierProfiles.Where(p => p.UserId == carrierId)
            .ExecuteUpdateAsync(s => s.SetProperty(p => p.CompletedJobCount, p => p.CompletedJobCount + 1), cancellationToken);
}
