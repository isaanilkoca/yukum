using FluentValidation;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Domain.Listings;

namespace Yukum.Application.Listings;

/// <summary>
/// İlan bilgilerini günceller. Yalnız ilanın sahibi ve yalnız hâlâ "Açık" ilan için: teklif kabul edilip iş atandıktan (ya da ilan
/// tamamlandıktan/kaldırıldıktan) sonra değiştirilemez, çünkü anlaşma eski bilgilere göre yapılmıştır.
/// Bekleyen teklifler korunur; taşımacı güncel ilan bilgisini Tekliflerim'de görür.
/// </summary>
public sealed class UpdateListingHandler(
    IValidator<CreateListingCommand> validator,
    IRepository<Listing> listings,
    IGeographyRepository geography,
    IUnitOfWork unitOfWork) : ICommandHandler<UpdateListingCommand, ListingDto>
{
    /// <summary>İlan yoksa/başkasınınsa 404; açık değilse 409; kurallara uymuyorsa ValidationException (400).</summary>
    public async Task<ListingDto> HandleAsync(UpdateListingCommand command, CancellationToken cancellationToken = default)
    {
        var listing = await listings.GetByIdAsync(command.ListingId, asNoTracking: false, cancellationToken);
        if (listing is null || listing.ShipperId != command.ShipperId)
            throw new NotFoundException("İlan bulunamadı.");   // başkasının ilanının varlığı sızdırılmaz (IDOR)

        if (listing.Status != ListingStatus.Open)
            throw new ConflictException(listing.Status == ListingStatus.Assigned
                ? "Teklif kabul edilmiş ilan güncellenemez."
                : "Tamamlanmış ya da kaldırılmış ilan güncellenemez.");

        // Doğrulama kuralları ilan açma ile aynı: tek kaynak (CreateListingValidator), kural kopyalanmaz.
        var asCreate = new CreateListingCommand(command.ShipperId, command.Title, command.Description, command.WeightKg,
            command.VehicleType, command.FromCityId, command.FromDistrictId, command.ToCityId, command.ToDistrictId,
            command.PickupDate, command.Budget);
        await validator.ValidateAndThrowAsync(asCreate, cancellationToken);

        listing.Title = command.Title!.Trim();
        listing.Description = string.IsNullOrWhiteSpace(command.Description) ? null : command.Description.Trim();
        listing.WeightKg = command.WeightKg;
        listing.VehicleType = command.VehicleType;
        listing.FromCityId = command.FromCityId;
        listing.FromDistrictId = command.FromDistrictId;
        listing.ToCityId = command.ToCityId;
        listing.ToDistrictId = command.ToDistrictId;
        listing.PickupDate = command.PickupDate;
        listing.Budget = command.Budget;

        await unitOfWork.SaveChangesAsync(cancellationToken);
        return CreateListingHandler.ToDto(listing,
            await CreateListingHandler.CityNamesAsync(geography, cancellationToken),
            await CreateListingHandler.DistrictNamesAsync(geography, [listing], cancellationToken));
    }
}
