using Yukum.Domain.Listings;

namespace Yukum.Application.Offers;

/// <summary>İstemcinin gönderdiği teklif (ilan numarası adresten, taşımacı jetondan gelir).</summary>
public sealed record CreateOfferRequest(decimal Amount, string? Note);

/// <summary>Komut: Taşımacı bir ilana teklif verir (varsa tutarını günceller).</summary>
public sealed record CreateOfferCommand(Guid ListingId, Guid CarrierId, decimal Amount, string? Note);

/// <summary>İstemciye giden teklif bilgisi.</summary>
public sealed record OfferDto(Guid Id, Guid ListingId, decimal Amount, string? Note, OfferStatus Status);
