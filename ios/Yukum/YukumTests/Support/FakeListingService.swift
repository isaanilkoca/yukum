//
//  FakeListingService.swift
//  YukumTests
//

import Foundation
@testable import Yukum

final class FakeListingService: ListingServicing {
    var myListingsResult: Result<[Listing], Error> = .success([])
    var openListingsResult: Result<Page<Listing>, Error> = .success(Sample.page([]))
    private(set) var openListingsCalls: [(filter: OpenListingsFilter, page: Int, lat: Double?, lon: Double?)] = [] // hangi filtre ve sayfayla çağrıldı
    private(set) var myListingsCalls = 0
    var createResult: Result<ListingResponse, Error> = .success(ListingResponse(id: "1", title: "t"))
    private(set) var createBodies: [CreateListingRequest] = []
    var cancelResult: Result<Void, Error> = .success(())
    private(set) var cancelledIds: [String] = []
    
    func create(_ body: CreateListingRequest) async throws -> ListingResponse { createBodies.append(body); return try createResult.get() }
    func myListings() async throws -> [Listing] { myListingsCalls += 1; return try myListingsResult.get() }
    var allMyListingsResult: Result<[Listing], Error> = .success([])
    func allMyListings() async throws -> [Listing] { try allMyListingsResult.get() }
    func openListings(filter: OpenListingsFilter, page: Int, lat: Double?, lon: Double?) async throws -> Page<Listing> {
        openListingsCalls.append((filter, page, lat, lon)); return try openListingsResult.get()
    }
    var favoriteResult: Result<Void, Error> = .success(())
    private(set) var favoriteCalls: [(listingId: String, isFavorite: Bool)] = []
    func setFavorite(listingId: String, isFavorite: Bool) async throws { favoriteCalls.append((listingId, isFavorite)); try favoriteResult.get() }
    var favoritesResult: Result<[Listing], Error> = .success([])
    func favorites() async throws -> [Listing] { try favoritesResult.get() }
    private(set) var viewedIds: [String] = []
    func recordView(listingId: String) async throws { viewedIds.append(listingId) }
    var statsResult: Result<ListingStats, Error> = .success(ListingStats(viewCount: 0, favoriteCount: 0, offerCount: 0))
    func stats(listingId: String) async throws -> ListingStats { try statsResult.get() }
    var priceReferenceResult: Result<PriceReference, Error> = .success(PriceReference(medianAmount: nil, sampleCount: 0))
    private(set) var priceReferenceCalls: [(fromCityId: Int, toCityId: Int, vehicleType: String)] = []
    func priceReference(fromCityId: Int, toCityId: Int, vehicleType: String) async throws -> PriceReference {
        priceReferenceCalls.append((fromCityId, toCityId, vehicleType)); return try priceReferenceResult.get()
    }
    func cancel(listingId: String) async throws { cancelledIds.append(listingId); try cancelResult.get() }
    
    
    var updateResult: Result<ListingResponse, Error> = .success(ListingResponse(id: "1", title: "t"))
    private(set) var updateCalls: [(id: String, body: CreateListingRequest)] = [] // testte hangi ilan, hangi paketle güncellendi diye bakarız
    func update(listingId: String, _ body: CreateListingRequest) async throws -> ListingResponse {
        updateCalls.append((listingId, body)); return try updateResult.get()
    }
}
