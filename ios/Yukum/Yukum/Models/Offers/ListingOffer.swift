//
//  ListingOffer.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: ListingOffer (ilana gelen teklif, Yük Veren) ────────────────
// │ MODEL     : Yük Veren'in ilanına gelen BEKLEYEN tek teklif: taşımacı adı, tutar, not, durum
// │ ÜRETEN    : Models/Services/OfferService.listingOffers ← GET /api/v1/listings/{id}/offers
// │ SAKLAYAN  : ViewModels/ListingOffersViewModel.offers → Views/ListingOffersView (List, Kabul/Reddet/Sohbet)
// │ SOHBET    : ViewModels/ChatContext.forShipperPending(_:) bu modelden sohbet açılış bilgisi üretir
// └──────────────────────────────────────────────────────────────────────

// ⮕ KULLANIM [ListingOffer]: kullanır: ChatContext › forShipperPending(), ListingOffersViewModel › offers, ListingOffersViewModel › decide(), ListingOffersViewModel › openChat(), OfferService › listingOffers(), OfferServicing › listingOffers() … +2
struct ListingOffer: Decodable, Identifiable { // Identifiable [SWIFT]: benzersiz id'si var, List'te id: yazmak gerekmez | Decodable [SWIFT]: JSON'dan bu türde değer üretilebilir
    // ⮕ KULLANIM [id]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let id: String // teklif numarası (GUID yazı gelir) | kabul/reddet uçlarına bu gider
    // ⮕ KULLANIM [carrierName]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let carrierName: String // teklifi veren taşımacının adı
    // ⮕ KULLANIM [amount]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let amount: Double // tutar | API 48000.0 gönderir
    // ⮕ KULLANIM [note]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let note: String? // isteğe bağlı not, yoksa nil
    // ⮕ KULLANIM [status]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let status: String // "Pending" / "Accepted" / "Rejected" (API durumu yazı olarak gönderir)
}
