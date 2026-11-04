//
//  ServiceProtocols.swift
//  Yukum
//

import Foundation

// BU DOSYA: servislerin "ne yapabildiğini" anlatan SÖZLEŞMELER (protocol).
// NEDEN: ViewModel'ler somut servise (ListingService) değil, sözleşmeye (ListingServicing) bağlı olur.
//   → gerçek uygulamada gerçek servis verilir, TESTTE sahte servis verilir (internet/sunucu gerekmez). Buna BAĞIMLILIK ENJEKSİYONU (Dependency Injection) denir.
// protocol [SWIFT]: "bu fonksiyonlara sahip olan her şey bu sözleşmeyi karşılar" | adlandırma: yaptığı işin sıfat hâli (...Servicing)
// BAĞLANTI: ViewModel/*.swift sözleşmeleri kullanır | gerçek servisler Network/*Service.swift (aşağıdaki extension'lar onları sözleşmeye bağlar) | sahte servisler YukumTests/Fakes.swift

protocol ListingServicing {
    func create(_ body: CreateListingRequest) async throws -> ListingResponse
    func myListings() async throws -> [Listing]
    func openListings(fromCityId: Int, fromDistrictId: Int, lat: Double?, lon: Double?) async throws -> [Listing]
    func cancel(listingId: String) async throws
}

protocol OfferServicing {
    func create(listingId: String, _ body: CreatOfferRequest) async throws -> offerResponse
    func listingOffers(listingId: String) async throws -> [ListingOffer]
    func decide(offerId: String, accept: Bool) async throws
    func myOffers() async throws -> [CarrierOffer]
    func unseenCount() async throws -> Int
    func markSeen() async throws
    func hide(offerId: String) async throws
    func shipperHistory() async throws -> [ShipperHistoryOffer]
}

protocol ChatServicing {
    func messages(offerId: String) async throws -> [ChatMessage]
    func send(offerId: String, _ body: SendMessageRequest) async throws
    func clear(offerId: String) async throws
    func complete(offerId: String) async throws
}

protocol CityServicing {
    func cities() async throws -> [City]
    func districts(cityId: Int) async throws -> [District]
}

protocol AuthServicing {
    func login(_ body: LoginRequest) async throws -> LoginResponse
}

// Gerçek servisler zaten bu fonksiyonlara sahip; "sen de bu sözleşmeyi karşılıyorsun" demek için boş extension yeter
extension ListingService: ListingServicing {}
extension OfferService: OfferServicing {}
extension ChatService: ChatServicing {}
extension CityService: CityServicing {}
extension AuthService: AuthServicing {}
