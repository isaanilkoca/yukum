using FluentValidation;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Application.Notifications;
using Yukum.Domain.Listings;
using Yukum.Domain.Notifications;

namespace Yukum.Application.Reviews;

/// <summary>Yük Veren, kendi ilanının tamamlanmış işini Taşımacı için puanlar (1–5 + kısa yorum). Her işe bir kez.</summary>
public sealed class CreateReviewHandler(
    IValidator<CreateReviewCommand> validator,
    IRepository<Offer> offers,
    IRepository<Listing> listings,
    IRepository<Review> reviews,
    IRepository<Notification> notifications,
    ICarrierDirectory carriers,
    IUnitOfWork unitOfWork) : ICommandHandler<CreateReviewCommand, ReviewDto>
{
    // FONKSİYON ROLÜ: API'NİN İŞ MANTIĞI | ReviewsController çağırır: doğrular, işin sahibi + tamamlanmış + daha önce puanlanmamış mı bakar,
    // yorumu ekler ve Taşımacı'nın ortalamasını AYNI İŞLEMDE (transaction) günceller
    /// <summary>İş yoksa ya da başkasınınsa 404; tamamlanmamışsa 409; zaten puanlanmışsa 409; puan geçersizse 400.</summary>
    public async Task<ReviewDto> HandleAsync(CreateReviewCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);

        var offer = await offers.GetByIdAsync(command.OfferId, asNoTracking: true, cancellationToken)
            ?? throw new NotFoundException("İş bulunamadı.");
        var listing = await listings.GetByIdAsync(offer.ListingId, asNoTracking: true, cancellationToken);
        if (listing is null || listing.ShipperId != command.ShipperId)
            throw new NotFoundException("İş bulunamadı.");   // başkasının işi: varlığı sızdırılmaz

        if (offer.Status != OfferStatus.Completed)
            throw new ConflictException("Yalnız tamamlanmış iş puanlanabilir.");
        if (await reviews.AnyAsync(r => r.OfferId == offer.Id, cancellationToken))
            throw new ConflictException("Bu iş için zaten puan verdin.");

        var review = new Review
        {
            OfferId = offer.Id, ListingId = listing.Id, CarrierId = offer.CarrierId, ShipperId = command.ShipperId,
            Rating = command.Rating, Comment = string.IsNullOrWhiteSpace(command.Comment) ? null : command.Comment.Trim()
        };

        // Yorum + ortalama güncellemesi TEK işlemde: biri başarısız olursa ikisi de geri alınır.
        await unitOfWork.ExecuteInTransactionAsync(async ct =>
        {
            reviews.Add(review);
            notifications.Add(NotificationFactory.ReviewReceived(offer.CarrierId, listing, offer.Id, review.Rating)); // yorumla aynı işlemde
            await unitOfWork.SaveChangesAsync(ct);                       // OfferId benzersiz indeksi: yarış durumunda ikinci yorum burada reddedilir
            await carriers.AddRatingAsync(offer.CarrierId, review.Rating, ct);
        }, cancellationToken);

        return new ReviewDto(review.Id, review.OfferId, review.Rating, review.Comment);
    }
}
