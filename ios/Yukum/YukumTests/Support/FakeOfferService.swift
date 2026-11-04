//
//  FakeOfferService.swift
//  YukumTests
//

import Foundation
@testable import Yukum

final class FakeOfferService: OfferServicing {
    var createResult: Result<OfferResponse, Error> = .success(OfferResponse(amount: 1000))
    private(set) var createCalls: [(listingId: String, body: CreateOfferRequest)] = []
    var listingOffersResult: Result<[ListingOffer], Error> = .success([])
    var decideResult: Result<Void, Error> = .success(())
    private(set) var decisions: [(id: String, accept: Bool)] = []
    var myOffersResult: Result<[CarrierOffer], Error> = .success([])
    var unseenResult: Result<Int, Error> = .success(0)
    var markSeenResult: Result<Void, Error> = .success(())
    private(set) var markSeenCalls = 0
    var hideResult: Result<Void, Error> = .success(())
    private(set) var hiddenIds: [String] = []
    var historyResult: Result<[ShipperHistoryOffer], Error> = .success([])

    func create(listingId: String, _ body: CreateOfferRequest) async throws -> OfferResponse { createCalls.append((listingId, body)); return try createResult.get() }
    func listingOffers(listingId: String) async throws -> [ListingOffer] { try listingOffersResult.get() }
    func decide(offerId: String, accept: Bool) async throws { decisions.append((offerId, accept)); try decideResult.get() }
    func myOffers() async throws -> [CarrierOffer] { try myOffersResult.get() }
    func unseenCount() async throws -> Int { try unseenResult.get() }
    func markSeen() async throws { markSeenCalls += 1; try markSeenResult.get() }
    func hide(offerId: String) async throws { hiddenIds.append(offerId); try hideResult.get() }
    func shipperHistory() async throws -> [ShipperHistoryOffer] { try historyResult.get() }
}
