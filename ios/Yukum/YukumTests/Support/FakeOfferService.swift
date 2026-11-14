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
    var withdrawResult: Result<Void, Error> = .success(())
    private(set) var withdrawnIds: [String] = []
    func withdraw(offerId: String) async throws { withdrawnIds.append(offerId); try withdrawResult.get() }
    var advanceResult: Result<Void, Error> = .success(())
    private(set) var advancedIds: [String] = []
    func advance(offerId: String) async throws { advancedIds.append(offerId); try advanceResult.get() }
    func shipperHistory() async throws -> [ShipperHistoryOffer] { try historyResult.get() }
    // karşılıklı iptal: çağrıları kaydeder | cancelResult ile hata denenebilir
    var cancelCalls: [String] = []
    var cancelResult: Result<Void, Error> = .success(())
    func requestCancel(offerId: String, reason: String, note: String?, reopenListing: Bool?) async throws { cancelCalls.append("request:\(offerId):\(reason):\(reopenListing.map(String.init) ?? "nil")"); try cancelResult.get() }
    func approveCancel(offerId: String, reopenListing: Bool?) async throws { cancelCalls.append("approve:\(offerId):\(reopenListing.map(String.init) ?? "nil")"); try cancelResult.get() }
    func rejectCancel(offerId: String) async throws { cancelCalls.append("reject:\(offerId)"); try cancelResult.get() }
    func withdrawCancel(offerId: String) async throws { cancelCalls.append("withdraw:\(offerId)"); try cancelResult.get() }
}
