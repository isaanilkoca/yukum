//
//  OfferServicing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: OfferServicing (sözleşme) ───────────────────────────────────
// │ GERÇEK    : Services/OfferService.swift | SAHTE (test): YukumTests/Support/FakeOfferService.swift
// │ KULLANAN  : ViewModels/HomeViewModel (unseenCount), MyOffersViewModel, ListingOffersViewModel, OldOffersViewModel, ListingDetailViewModel
// └──────────────────────────────────────────────────────────────────────

protocol OfferServicing {
    func create(listingId: String, _ body: CreateOfferRequest) async throws -> OfferResponse
    func listingOffers(listingId: String) async throws -> [ListingOffer]
    func decide(offerId: String, accept: Bool) async throws
    func myOffers() async throws -> [CarrierOffer]
    func unseenCount() async throws -> Int
    func markSeen() async throws
    func hide(offerId: String) async throws
    func shipperHistory() async throws -> [ShipperHistoryOffer]
}
