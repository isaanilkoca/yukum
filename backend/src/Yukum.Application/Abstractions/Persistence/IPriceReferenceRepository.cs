using Yukum.Domain.Accounts;

namespace Yukum.Application.Abstractions.Persistence;

/// <summary>Emsal fiyat için tamamlanmış işlerin tutarlarını okur (EF'e bağımlı kısım Infrastructure'da).</summary>
public interface IPriceReferenceRepository
{
    /// <summary>Aynı rota ve araç tipinde, <paramref name="since"/> tarihinden sonra karara bağlanmış TAMAMLANMIŞ işlerin kabul edilen tutarları (en yeniden eskiye, en çok <paramref name="take"/>).</summary>
    Task<IReadOnlyList<decimal>> ListCompletedAmountsAsync(
        int fromCityId, int toCityId, VehicleType vehicleType, DateTime since, int take, CancellationToken cancellationToken = default);
}
