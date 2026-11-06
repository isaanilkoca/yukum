//
//  FavoritesAndStatsTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// Favori kalbi, Favoriler listesi, görüntülenme ve ilan sahibi sayaçları | sunucu gerekmez, sahte servis verilir
@MainActor
struct FavoritesAndStatsTests {

    private func detail(isFavorite: Bool = false) -> (ListingDetailViewModel, FakeListingService) {
        let listings = FakeListingService()
        let vm = ListingDetailViewModel(listing: Sample.listing("L1", isFavorite: isFavorite), service: FakeOfferService(), listingService: listings)
        return (vm, listings)
    }

    // ── Kalp ──
    @Test func heart_startsFromTheListingAndFlipsImmediately_thenTellsTheServer() async {
        let (vm, listings) = detail(isFavorite: false)
        #expect(!vm.isFavorite)

        await vm.toggleFavorite()
        #expect(vm.isFavorite)
        #expect(listings.favoriteCalls.last?.listingId == "L1")
        #expect(listings.favoriteCalls.last?.isFavorite == true)

        await vm.toggleFavorite() // tekrar basınca favoriden çıkar
        #expect(!vm.isFavorite)
        #expect(listings.favoriteCalls.last?.isFavorite == false)
    }

    @Test func heart_revertsAndShowsTheMessage_whenTheServerRefuses() async {
        let (vm, listings) = detail(isFavorite: false)
        listings.favoriteResult = .failure(APIError(message: "İlan bulunamadı."))

        await vm.toggleFavorite()

        #expect(!vm.isFavorite) // iyimser güncelleme geri alındı
        #expect(vm.errorMessage == "İlan bulunamadı.")
    }

    @Test func heart_alreadyFavoriteListing_startsFilled() {
        #expect(detail(isFavorite: true).0.isFavorite)
    }

    @Test func opening_theDetail_recordsAView() async {
        let (vm, listings) = detail()
        await vm.recordView()
        #expect(listings.viewedIds == ["L1"])
    }

    // ── Favoriler ekranı ──
    @Test func favorites_loadAndRemoveReloadsTheList() async {
        let service = FakeListingService()
        let vm = FavoritesViewModel(service: service)
        service.favoritesResult = .success([Sample.listing("a", isFavorite: true), Sample.listing("b", isFavorite: true)])
        await vm.load()
        #expect(vm.listings.map(\.id) == ["a", "b"])

        service.favoritesResult = .success([Sample.listing("b", isFavorite: true)]) // sunucunun yeni cevabı
        await vm.remove(vm.listings[0])

        #expect(service.favoriteCalls.last?.listingId == "a")
        #expect(service.favoriteCalls.last?.isFavorite == false)
        #expect(vm.listings.map(\.id) == ["b"])
        #expect(vm.errorMessage == nil)
    }

    @Test func favorites_failureShowsTheMessage_andKeepsTheList() async {
        let service = FakeListingService()
        let vm = FavoritesViewModel(service: service)
        service.favoritesResult = .success([Sample.listing("a", isFavorite: true)])
        await vm.load()

        service.favoriteResult = .failure(APIError(message: "Favori güncellenemedi."))
        await vm.remove(vm.listings[0])

        #expect(vm.errorMessage == "Favori güncellenemedi.")
        #expect(vm.listings.map(\.id) == ["a"]) // liste bozulmadı
    }

    // ── İlan sahibi sayaçları ──
    @Test func ownerStats_loadForTheListing_andFailureIsSilent() async {
        let listings = FakeListingService()
        listings.statsResult = .success(ListingStats(viewCount: 12, favoriteCount: 3, offerCount: 2))
        let vm = ListingOffersViewModel(listing: Sample.listing("L1"), offerService: FakeOfferService(), listingService: listings)
        #expect(vm.stats == nil) // yüklenmeden kart çizilmez

        await vm.loadStats()
        #expect(vm.stats?.viewCount == 12 && vm.stats?.favoriteCount == 3 && vm.stats?.offerCount == 2)

        listings.statsResult = .failure(StubError())
        await vm.loadStats()
        #expect(vm.stats == nil) // hata: kartlar kaybolur, ekranın geri kalanı etkilenmez
        #expect(vm.errorMessage == nil)
    }

    // ── JSON ──
    @Test func decodes_isFavoriteOnListings_andTheStats() throws {
        let listing = try JSONDecoder().decode(Listing.self, from: Data("""
        {"id":"l1","title":"İlan","weightKg":1000,"fromCityName":"Mersin","fromDistrictName":"Mezitli","toCityName":"İstanbul","toDistrictName":"Kadıköy",
         "pickupDate":"2026-12-01","budget":5000,"myOfferAmount":null,"myOfferStatus":null,"distanceKm":null,"description":null,"vehicleType":"Truck",
         "fromCityId":33,"fromDistrictId":1,"toCityId":34,"toDistrictId":2,"isFavorite":true}
        """.utf8))
        #expect(listing.isFavorite)

        let stats = try JSONDecoder().decode(ListingStats.self, from: Data(#"{"viewCount":4,"favoriteCount":1,"offerCount":0}"#.utf8))
        #expect(stats.viewCount == 4 && stats.favoriteCount == 1 && stats.offerCount == 0)
    }
}
