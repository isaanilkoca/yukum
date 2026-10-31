using FluentValidation;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Domain.Listings;

namespace Yukum.Application.Listings;

/// <summary>İlanı doğrular, kaydeder ve oluşan ilanı döndürür.</summary>
public sealed class CreateListingHandler(
    IValidator<CreateListingCommand> validator,
    IRepository<Listing> listings,
    IGeographyRepository geography,
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
        return ToDto(listing, await CityNamesAsync(geography, cancellationToken));
    }

    /// <summary>İl numarası → il adı sözlüğü (il listesi önbellekli olduğu için ucuzdur).</summary>
    internal static async Task<Dictionary<int, string>> CityNamesAsync(IGeographyRepository geography, CancellationToken ct) =>
        (await geography.ListCitiesAsync(ct)).ToDictionary(c => c.Id, c => c.Name);

    /// <summary>İlanı istemciye giden modele çevirir; il adlarını sözlükten alır.</summary>
    internal static ListingDto ToDto(Listing l, IReadOnlyDictionary<int, string> cityNames) => new(l.Id, l.Title, l.Description,
        l.WeightKg, l.VehicleType, l.FromCityId, cityNames[l.FromCityId], l.FromDistrictId, l.ToCityId, cityNames[l.ToCityId],
        l.ToDistrictId, l.PickupDate, l.Budget, l.CreatedAt);
}

/// <summary>Yük Veren'in kendi ilanlarını yeniden eskiye sıralı getirir.</summary>
public sealed class GetMyListingsHandler(IRepository<Listing> listings, IGeographyRepository geography)
    : IQueryHandler<GetMyListingsQuery, IReadOnlyList<ListingDto>>
{
    /// <summary>Yalnız jetondaki kullanıcının ilanları döner.</summary>
    public async Task<IReadOnlyList<ListingDto>> HandleAsync(GetMyListingsQuery query, CancellationToken cancellationToken = default)
    {
        var mine = await listings.ListAsync(l => l.ShipperId == query.ShipperId, asNoTracking: true, cancellationToken);
        var names = await CreateListingHandler.CityNamesAsync(geography, cancellationToken);
        return mine.OrderByDescending(l => l.CreatedAt).Select(l => CreateListingHandler.ToDto(l, names)).ToList();
    }
}

/// <summary>Taşımacı için açık ilanları yeniden eskiye sıralı getirir.</summary>
public sealed class GetOpenListingsHandler(IRepository<Listing> listings, IGeographyRepository geography)
    : IQueryHandler<GetOpenListingsQuery, IReadOnlyList<ListingDto>>
{
    /// <summary>Yalnız durumu Open olan ilanlar döner.</summary>
    public async Task<IReadOnlyList<ListingDto>> HandleAsync(GetOpenListingsQuery query, CancellationToken cancellationToken = default)
    {
        var open = await listings.ListAsync(l => l.Status == ListingStatus.Open, asNoTracking: true, cancellationToken);
        var names = await CreateListingHandler.CityNamesAsync(geography, cancellationToken);
        return open.OrderByDescending(l => l.CreatedAt).Select(l => CreateListingHandler.ToDto(l, names)).ToList();
    }
}
