//
//  Fakes.swift
//  YukumTests
//

import Foundation
@testable import Yukum

// SAHTE SERVİSLER: ViewModel testlerinde gerçek servis yerine kullanılır. İnternet/sunucu gerekmez, cevabı BİZ belirleriz, hangi çağrı yapıldı kaydedilir.
// Bu mümkün çünkü ViewModel'ler somut servise değil sözleşmeye (Network/ServiceProtocols.swift) bağlı.

struct StubError: Error {} // testte "bir şey ters gitti" demek için

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
}

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

final class FakeChatService: ChatServicing {
    var messagesResult: Result<[ChatMessage], Error> = .success([])
    private(set) var messageLoads = 0
    var sendResult: Result<Void, Error> = .success(())
    private(set) var sent: [String] = []
    var clearResult: Result<Void, Error> = .success(())
    private(set) var clearCalls = 0
    var completeResult: Result<Void, Error> = .success(())
    private(set) var completeCalls = 0

    func messages(offerId: String) async throws -> [ChatMessage] { messageLoads += 1; return try messagesResult.get() }
    func send(offerId: String, _ body: SendMessageRequest) async throws { sent.append(body.text); try sendResult.get() }
    func clear(offerId: String) async throws { clearCalls += 1; try clearResult.get() }
    func complete(offerId: String) async throws { completeCalls += 1; try completeResult.get() }
}

final class FakeCityService: CityServicing {
    var citiesResult: Result<[City], Error> = .success([])
    private(set) var citiesCalls = 0
    var districtsResult: Result<[District], Error> = .success([])
    private(set) var districtCalls: [Int] = []

    func cities() async throws -> [City] { citiesCalls += 1; return try citiesResult.get() }
    func districts(cityId: Int) async throws -> [District] { districtCalls.append(cityId); return try districtsResult.get() }
}

final class FakeAuthService: AuthServicing {
    var loginResult: Result<LoginResponse, Error> = .failure(StubError())
    private(set) var loginBodies: [LoginRequest] = []
    func login(_ body: LoginRequest) async throws -> LoginResponse { loginBodies.append(body); return try loginResult.get() }
}

// Test verisi üretici yardımcıları (alan çokluğundan testleri okunur tutmak için)
enum Sample {
    static let shipper = LoginUser(id: "s1", displayName: "Yük Veren", role: "Shipper")
    static let carrier = LoginUser(id: "c1", displayName: "Taşımacı", role: "Carrier")

    static func listing(_ id: String = "l1", title: String = "İlan") -> Listing {
        Listing(id: id, title: title, weightKg: 1000, fromCityName: "Mersin", fromDistrictName: "Mezitli", toCityName: "İstanbul", toDistrictName: "Kadıköy",
                pickupDate: "2026-12-01", budget: 5000, myOfferAmount: nil, myOfferStatus: nil, distanceKm: nil)
    }
    static func listingOffer(_ id: String = "o1", status: String = "Pending") -> ListingOffer {
        ListingOffer(id: id, carrierName: "Taşımacı", amount: 1000, note: nil, status: status)
    }
    static func carrierOffer(_ id: String = "o1", status: String = "Pending", isNew: Bool = false) -> CarrierOffer {
        CarrierOffer(id: id, listingTitle: "İlan", fromCityName: "Mersin", toCityName: "İstanbul", amount: 1000, status: status, isNew: isNew,
                     fromDistrictName: "Mezitli", toDistrictName: "Kadıköy", shipperName: "Yük Veren", weightKg: 1000, pickupDate: "2026-12-01")
    }
    static func historyOffer(_ id: String = "o1", status: String = "Accepted") -> ShipperHistoryOffer {
        ShipperHistoryOffer(id: id, listingTitle: "İlan", fromCityName: "Mersin", fromDistrictName: "Mezitli", toCityName: "İstanbul", toDistrictName: "Kadıköy",
                            weightKg: 1000, pickupDate: "2026-12-01", carrierName: "Taşımacı", amount: 1000, status: status)
    }
    static func message(_ id: String = "m1", text: String = "Merhaba", mine: Bool = true) -> ChatMessage {
        ChatMessage(id: id, text: text, createdAt: "2026-11-04T10:00:00Z", isMine: mine)
    }
}

final class FakeSession: SessionRestoring {
    var result: Result<LoginUser?, Error> = .success(nil)
    private(set) var restoreCalls = 0
    func restore() async throws -> LoginUser? { restoreCalls += 1; return try result.get() }
}
