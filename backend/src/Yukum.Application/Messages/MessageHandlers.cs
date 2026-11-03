using FluentValidation;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Domain.Listings;

namespace Yukum.Application.Messages;

/// <summary>Sohbete katılma yetkisi: yalnız teklifi veren taşımacı ve ilanın sahibi. Başkasına 404 (sohbetin varlığı sızdırılmaz).</summary>
internal static class ChatAccess
{
    /// <summary>Teklifi getirir; kullanıcı taraf değilse NotFoundException fırlatır.</summary>
    public static async Task<Offer> RequireParticipantAsync(
        IRepository<Offer> offers, IRepository<Listing> listings, Guid offerId, Guid userId, CancellationToken ct)
    {
        var offer = await offers.GetByIdAsync(offerId, asNoTracking: true, ct) ?? throw new NotFoundException("Sohbet bulunamadı.");
        if (offer.CarrierId == userId) return offer;
        var listing = await listings.GetByIdAsync(offer.ListingId, asNoTracking: true, ct);
        if (listing is not null && listing.ShipperId == userId) return offer;
        throw new NotFoundException("Sohbet bulunamadı.");
    }
}

/// <summary>Bir teklifin mesajlarını eskiden yeniye getirir.</summary>
public sealed class GetMessagesHandler(IRepository<Offer> offers, IRepository<Listing> listings, IRepository<Message> messages)
    : IQueryHandler<GetMessagesQuery, IReadOnlyList<MessageDto>>
{
    /// <summary>Taraf olmayana 404. Reddedilmiş tekliflerin eski mesajları okunabilir.</summary>
    public async Task<IReadOnlyList<MessageDto>> HandleAsync(GetMessagesQuery query, CancellationToken cancellationToken = default)
    {
        var offer = await ChatAccess.RequireParticipantAsync(offers, listings, query.OfferId, query.UserId, cancellationToken);
        // Kullanıcının kendi sildiği mesajlar görünmez (taşımacı ise HiddenByCarrier, yük veren ise HiddenByShipper bakılır).
        var isCarrier = offer.CarrierId == query.UserId;
        var list = await messages.ListAsync(
            m => m.OfferId == query.OfferId && (isCarrier ? !m.HiddenByCarrier : !m.HiddenByShipper),
            asNoTracking: true, cancellationToken);
        return list.OrderBy(m => m.CreatedAt).Select(m => new MessageDto(m.Id, m.Text, m.CreatedAt, m.SenderId == query.UserId)).ToList();
    }
}

/// <summary>Sohbete mesaj ekler. Reddedilmiş ya da tamamlanmış teklifte yazılamaz.</summary>
public sealed class SendMessageHandler(
    IValidator<SendMessageCommand> validator,
    IRepository<Offer> offers,
    IRepository<Listing> listings,
    IRepository<Message> messages,
    IUnitOfWork unitOfWork) : ICommandHandler<SendMessageCommand, MessageDto>
{
    /// <summary>Doğrulama hatası 400, taraf değilse 404, teklif reddedilmişse 409.</summary>
    public async Task<MessageDto> HandleAsync(SendMessageCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);
        var offer = await ChatAccess.RequireParticipantAsync(offers, listings, command.OfferId, command.UserId, cancellationToken);
        if (offer.Status == OfferStatus.Rejected)
            throw new ConflictException("Reddedilen teklifte sohbet kapalı.");
        if (offer.Status == OfferStatus.Completed)
            throw new ConflictException("İş tamamlandı, sohbet kapalı.");   // iki tarafta da kilitli

        var message = new Message { OfferId = offer.Id, SenderId = command.UserId, Text = command.Text!.Trim() };
        messages.Add(message);
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return new MessageDto(message.Id, message.Text, message.CreatedAt, IsMine: true);
    }
}

/// <summary>Sohbeti kullanıcının KENDİ görünümünden siler: o ana kadarki mesajlar onun için gizlenir, karşı taraf görmeye devam eder.</summary>
public sealed class ClearChatHandler(IRepository<Offer> offers, IRepository<Listing> listings, IRepository<Message> messages, IUnitOfWork unitOfWork)
    : ICommandHandler<ClearChatCommand, bool>
{
    /// <summary>Taraf olmayana 404. Sonradan yazılan yeni mesajlar normal görünür.</summary>
    public async Task<bool> HandleAsync(ClearChatCommand command, CancellationToken cancellationToken = default)
    {
        var offer = await ChatAccess.RequireParticipantAsync(offers, listings, command.OfferId, command.UserId, cancellationToken);
        var isCarrier = offer.CarrierId == command.UserId;

        // Değiştirilecek kayıtlar izlenerek alınır (asNoTracking: false): alanlar değişince SaveChanges kaydeder.
        var mine = await messages.ListAsync(m => m.OfferId == command.OfferId, asNoTracking: false, cancellationToken);
        foreach (var m in mine)
        {
            if (isCarrier) m.HiddenByCarrier = true; else m.HiddenByShipper = true;
        }

        await unitOfWork.SaveChangesAsync(cancellationToken);
        return true;
    }
}
