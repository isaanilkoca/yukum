using FluentValidation;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Domain.Listings;

namespace Yukum.Application.Offers;

/// <summary>Teklifi doğrular; ilan açıksa yeni teklif ekler, aynı taşımacının eski teklifi varsa tutarını günceller.</summary>
public sealed class CreateOfferHandler(
    IValidator<CreateOfferCommand> validator,
    IRepository<Listing> listings,
    IRepository<Offer> offers,
    IUnitOfWork unitOfWork) : ICommandHandler<CreateOfferCommand, OfferDto>
{
    // FONKSİYON ROLÜ: API'NİN İŞ MANTIĞI | OffersController çağırır: tutarı doğrular, ilan açık mı bakar, yeni teklif ekler ya da eskisinin tutarını günceller, DB'ye yazar
    /// <summary>İlan yoksa NotFoundException (404), ilan açık değilse ConflictException (409) fırlatır.</summary>
    public async Task<OfferDto> HandleAsync(CreateOfferCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);

        var listing = await listings.GetByIdAsync(command.ListingId, asNoTracking: true, cancellationToken)
            ?? throw new NotFoundException("İlan bulunamadı.");
        if (listing.Status != ListingStatus.Open)
            throw new ConflictException("Bu ilan artık teklif almıyor.");

        var note = string.IsNullOrWhiteSpace(command.Note) ? null : command.Note.Trim();

        // Bu taşımacının bu ilanda eski teklifi var mı? (izlenerek alınır: alanları değişince SaveChanges kaydeder)
        var existing = (await offers.ListAsync(o => o.ListingId == command.ListingId && o.CarrierId == command.CarrierId,
            asNoTracking: false, cancellationToken)).FirstOrDefault();

        if (existing is null)
        {
            existing = new Offer { ListingId = command.ListingId, CarrierId = command.CarrierId, Amount = command.Amount, Note = note };
            offers.Add(existing);
        }
        else
        {
            existing.Amount = command.Amount;
            existing.Note = note;
        }

        await unitOfWork.SaveChangesAsync(cancellationToken);
        return new OfferDto(existing.Id, existing.ListingId, existing.Amount, existing.Note, existing.Status);
    }
}
