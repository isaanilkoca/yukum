//
//  OfferServicing.swift
//  Yukum
//

import Foundation

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
