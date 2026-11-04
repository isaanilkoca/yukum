//
//  FakeListingService.swift
//  YukumTests
//

import Foundation
@testable import Yukum

final class FakeListingService: ListingServicing {
    var myListingsResult: Result<[Listing], Error> = .success([])
    var openListingsResult: Result<[Listing], Error> = .success([])
    private(set) var openListingsCalls: [(city: Int, district: Int, lat: Double?, lon: Double?)] = [] // hangi filtreyle çağrıldı
    private(set) var myListingsCalls = 0
    var createResult: Result<ListingResponse, Error> = .success(ListingResponse(id: "1", title: "t"))
    private(set) var createBodies: [CreateListingRequest] = []
    var cancelResult: Result<Void, Error> = .success(())
    private(set) var cancelledIds: [String] = []
    
    func create(_ body: CreateListingRequest) async throws -> ListingResponse { createBodies.append(body); return try createResult.get() }
    func myListings() async throws -> [Listing] { myListingsCalls += 1; return try myListingsResult.get() }
    func openListings(fromCityId: Int, fromDistrictId: Int, lat: Double?, lon: Double?) async throws -> [Listing] {
        openListingsCalls.append((fromCityId, fromDistrictId, lat, lon)); return try openListingsResult.get()
    }
    func cancel(listingId: String) async throws { cancelledIds.append(listingId); try cancelResult.get() }
    
    
    var updateResult: Result<ListingResponse, Error> = .success(ListingResponse(id: "1", title: "t"))
    private(set) var updateCalls: [(id: String, body: CreateListingRequest)] = [] // testte hangi ilan, hangi paketle güncellendi diye bakarız
    func update(listingId: String, _ body: CreateListingRequest) async throws -> ListingResponse {
        updateCalls.append((listingId, body)); return try updateResult.get()
    }
}
