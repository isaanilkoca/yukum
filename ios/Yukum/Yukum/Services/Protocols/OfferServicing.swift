//
//  OfferServicing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: OfferServicing (sözleşme) ───────────────────────────────────
// │ GERÇEK    : Services/OfferService.swift | SAHTE (test): YukumTests/Support/FakeOfferService.swift
// │ KULLANAN  : ViewModels/HomeViewModel (unseenCount), MyOffersViewModel, ListingOffersViewModel, OldOffersViewModel, ListingDetailViewModel
// │ HAZIR (Swift/Apple) [SWIFT] : async, throws, protocol, String, Int, Bool
// │ BİZİM (bizim yazdığımız) [BİZİM] : türler: OfferServicing | fonksiyonlar: create, listingOffers, decide, myOffers, unseenCount, markSeen, hide, shipperHistory
// └──────────────────────────────────────────────────────────────────────

protocol OfferServicing { // protocol [SWIFT]: sözleşme: "bu fonksiyonlara sahip olan her şey bu sözleşmeyi karşılar"
    func create(listingId: String, _ body: CreateOfferRequest) async throws -> OfferResponse // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
    func listingOffers(listingId: String) async throws -> [ListingOffer]
    func decide(offerId: String, accept: Bool) async throws
    func myOffers() async throws -> [CarrierOffer]
    func unseenCount() async throws -> Int
    func markSeen() async throws
    func hide(offerId: String) async throws
    func shipperHistory() async throws -> [ShipperHistoryOffer]
}
