//
//  ListingOffer.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: ListingOffer (ilana gelen teklif, Yük Veren) ────────────────
// │ MODEL     : Yük Veren'in ilanına gelen BEKLEYEN tek teklif: taşımacı adı, tutar, not, durum
// │ ÜRETEN    : Services/OfferService.listingOffers ← GET /api/v1/listings/{id}/offers
// │ SAKLAYAN  : ViewModels/ListingOffersViewModel.offers → Views/ListingOffersView (List, Kabul/Reddet/Sohbet)
// │ SOHBET    : ViewModels/ChatContext.forShipperPending(_:) bu modelden sohbet açılış bilgisi üretir
// └──────────────────────────────────────────────────────────────────────

struct ListingOffer: Decodable, Identifiable { // Identifiable [SWIFT]: benzersiz id'si var, List'te id: yazmak gerekmez | Decodable [SWIFT]: JSON'dan bu türde değer üretilebilir
    let id: String // teklif numarası (GUID yazı gelir) | kabul/reddet uçlarına bu gider
    let carrierName: String // teklifi veren taşımacının adı
    let amount: Double // tutar | API 48000.0 gönderir
    let note: String? // isteğe bağlı not, yoksa nil
    let status: String // "Pending" / "Accepted" / "Rejected" (API durumu yazı olarak gönderir)
}
