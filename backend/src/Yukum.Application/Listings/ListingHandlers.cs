using FluentValidation;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Domain.Listings;

namespace Yukum.Application.Listings;

/// <summary>İlanı doğrular, kaydeder ve oluşan ilanı döndürür.</summary>
public sealed class CreateListingHandler(
    IValidator<CreateListingCommand> validator,
    IRepository<Listing> listings,
    IUnitOfWork unitOfWork) : ICommandHandler<CreateListingCommand, ListingDto>
{
    /// <summary>Doğrulama hatasında ValidationException fırlatır (API'de 400).</summary>
    public async Task<ListingDto> HandleAsync(CreateListingCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);

        var listing = new Listing
        {
            ShipperId = command.ShipperId,
            Title = command.Title!.Trim(),
            Description = string.IsNullOrWhiteSpace(command.Description) ? null : command.Description.Trim(),
            WeightKg = command.WeightKg,
            VehicleType = command.VehicleType,
            FromCityId = command.FromCityId,
            FromDistrictId = command.FromDistrictId,
            ToCityId = command.ToCityId,
            ToDistrictId = command.ToDistrictId,
            PickupDate = command.PickupDate,
            Budget = command.Budget,
            Status = ListingStatus.Open
        };

        listings.Add(listing);
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return ToDto(listing);
    }

    internal static ListingDto ToDto(Listing l) => new(l.Id, l.Title, l.Description, l.WeightKg, l.VehicleType,
        l.FromCityId, l.FromDistrictId, l.ToCityId, l.ToDistrictId, l.PickupDate, l.Budget, l.CreatedAt);
}

/// <summary>Yük Veren'in kendi ilanlarını yeniden eskiye sıralı getirir.</summary>
public sealed class GetMyListingsHandler(IRepository<Listing> listings)
    : IQueryHandler<GetMyListingsQuery, IReadOnlyList<ListingDto>>
{
    /// <summary>Yalnız jetondaki kullanıcının ilanları döner.</summary>
    public async Task<IReadOnlyList<ListingDto>> HandleAsync(GetMyListingsQuery query, CancellationToken cancellationToken = default)
    {
        var mine = await listings.ListAsync(l => l.ShipperId == query.ShipperId, asNoTracking: true, cancellationToken);
        return mine.OrderByDescending(l => l.CreatedAt).Select(CreateListingHandler.ToDto).ToList();
    }
}
