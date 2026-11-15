using FluentValidation;
using FluentValidation.Results;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Application.Notifications;
using Yukum.Domain.Listings;
using Yukum.Domain.Notifications;

namespace Yukum.Application.Offers;

/// <summary>Teklifi doğrular; ilan açıksa yeni teklif ekler, aynı taşımacının eski teklifi varsa tutarını günceller.</summary>
public sealed class CreateOfferHandler(
    IValidator<CreateOfferCommand> validator,
    IRepository<Listing> listings,
    IRepository<Offer> offers,
    IRepository<Notification> notifications,
    IRepository<Yukum.Domain.Accounts.Vehicle> vehicles,
    IUnitOfWork unitOfWork,
    IBlockRepository blocks) : ICommandHandler<CreateOfferCommand, OfferDto>
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
        // ENGEL (15 Kasım): Taşımacı ile ilan sahibi arasında (hangi yönden olursa olsun) engel varsa teklif yok.
        //   Normalde ilan listede zaten görünmez (ListingSearchRepository); bu kontrol eski ekrandan/doğrudan istekten gelen teklifi durdurur.
        if (await blocks.IsBlockedEitherWayAsync(command.CarrierId, listing.ShipperId, cancellationToken))
            throw new ConflictException("Bu ilana teklif veremezsin.");

        // ARAÇ ŞARTI (15 Kasım, kullanıcı kararı): aracı olmayan Taşımacı teklif veremez. Kayıtta araç artık sorulmuyor,
        //   bu yüzden kontrol burada. Mesajdaki "Araçlarım" kelimesi iOS'ta "Araç ekle" düğmesini çıkarır (ListingDetailView).
        if (!await vehicles.AnyAsync(v => v.CarrierId == command.CarrierId, cancellationToken))
            throw new ConflictException("Teklif verebilmek için önce Araçlarım'dan en az bir araç ekle.");

        // ARAÇ SEÇİMİ (15 Kasım): teklif HANGİ araçla veriliyor? Seçilmediyse ve tek aracı varsa o; birden çoksa seçmesi istenir.
        //   Aracın marka/model/yılı dolu olmalı (eski kayıtlar boş olabilir): Yük Veren aracın kalitesini görerek karar verir.
        var mine = await vehicles.ListAsync(v => v.CarrierId == command.CarrierId, asNoTracking: true, cancellationToken);
        var vehicle = command.VehicleId is { } vid ? mine.FirstOrDefault(v => v.Id == vid) : mine.Count == 1 ? mine[0] : null;
        if (vehicle is null)
            throw new ValidationException([new ValidationFailure("vehicleId", command.VehicleId is null ? "Teklif için aracını seç." : "Araç bulunamadı.")]);
        if (!vehicle.HasDetails)
            throw new ValidationException([new ValidationFailure("vehicleId", "Seçtiğin aracın marka, model ve yılını Araçlarım'dan tamamla.")]);

        // TESLİM TARİHİ: yükleme tarihinden önce olamaz (yük alınmadan teslim edilemez), en çok 90 gün sonrası (gerçekçi söz).
        var delivery = command.EstimatedDeliveryDate!.Value;
        if (delivery < listing.PickupDate)
            throw new ValidationException([new ValidationFailure("estimatedDeliveryDate", "Teslim tarihi yükleme tarihinden önce olamaz.")]);
        if (delivery > listing.PickupDate.AddDays(90))
            throw new ValidationException([new ValidationFailure("estimatedDeliveryDate", "Teslim tarihi yükleme tarihinden en fazla 90 gün sonra olabilir.")]);

        var note = string.IsNullOrWhiteSpace(command.Note) ? null : command.Note.Trim();

        // Bu taşımacının bu ilanda eski teklifi var mı? (izlenerek alınır: alanları değişince SaveChanges kaydeder)
        // Karşılıklı iptal edilmiş eski teklif GÜNCELLENMEZ (geçmişte "Karşılıklı iptal" olarak kalır): yeniden yayınlanan ilana YENİ teklif kaydı açılır (15 Kasım).
        var existing = (await offers.ListAsync(o => o.ListingId == command.ListingId && o.CarrierId == command.CarrierId && !o.MutuallyCancelled,
            asNoTracking: false, cancellationToken)).FirstOrDefault();

        var isNew = existing is null;
        if (existing is null)
        {
            existing = new Offer { ListingId = command.ListingId, CarrierId = command.CarrierId, Amount = command.Amount, Note = note };
            offers.Add(existing);
        }
        else
        {
            existing.Amount = command.Amount;
            existing.Note = note;
            existing.Status = OfferStatus.Pending; // reddedilmiş teklifi güncelleyen taşımacı yeniden beklemeye girer
            existing.DecidedAt = null;
            existing.HiddenByCarrier = false; // sildiği teklife yeniden teklif verirse geri görünür
            existing.HiddenByShipper = false;
        }
        // Araç kopyası + teslim tarihi (yeni teklifte de güncellemede de)
        existing.VehicleId = vehicle.Id;
        existing.VehicleType = vehicle.Type;
        existing.VehicleBrand = vehicle.Brand;
        existing.VehicleModel = vehicle.Model;
        existing.VehicleYear = vehicle.Year;
        existing.EstimatedDeliveryDate = delivery;

        // Bildirim, teklifle AYNI SaveChanges'te yazılır (biri olmadan diğeri olmaz). Ekleme sırasında EF teklif numarasını üretmiş olur.
        notifications.Add(NotificationFactory.OfferReceived(listing.ShipperId, listing, existing.Id, existing.Amount, updated: !isNew));
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return new OfferDto(existing.Id, existing.ListingId, existing.Amount, existing.Note, existing.Status);
    }
}
