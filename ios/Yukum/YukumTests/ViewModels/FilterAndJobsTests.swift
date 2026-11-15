//
//  FilterAndJobsTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// 15 Kasım: sahibinden tarzı filtre (uzaklık + ağırlık + kapsüller) ve Devam Eden İşler kapsamı
@MainActor
struct FilterAndJobsTests {

    @Test func distanceIsSentOnlyWithALocation_andWorksWithOtherFilters() {
        var f = OpenListingsFilter(); f.maxDistanceKm = 50; f.minBudget = 1000; f.maxWeightKg = 5000
        let withLocation = f.queryItems(page: 1, pageSize: 20, lat: 36.8, lon: 34.6)
        #expect(withLocation.contains(URLQueryItem(name: "maxDistanceKm", value: "50")))
        #expect(withLocation.contains(URLQueryItem(name: "minBudget", value: "1000")))
        #expect(withLocation.contains(URLQueryItem(name: "maxWeightKg", value: "5000")))
        #expect(!f.queryItems(page: 1, pageSize: 20, lat: nil, lon: nil).contains { $0.name == "maxDistanceKm" }) // konumsuz gönderilmez (sunucu 400 verirdi)
        #expect(f.extraCount == 3)
    }

    @Test func activeFiltersShowAsChips_andEachChipRemovesOnlyItself() {
        let vm = HomeViewModel(user: Sample.carrier, listingService: FakeListingService(), offerService: FakeOfferService(),
                               cityService: FakeCityService(), session: FakeSession(), location: FakeLocation())
        var f = OpenListingsFilter(); f.maxDistanceKm = 100; f.vehicleType = "Truck"; f.minBudget = 5000
        vm.applyFilter(f)
        #expect(vm.usesLocation) // uzaklık filtresi konumu kullanır (Yakınımdakiler kapalı olsa da)
        #expect(vm.filterChips.map(\.id) == ["distance", "price", "vehicle"])

        vm.removeChip("vehicle")
        #expect(vm.filter.vehicleType.isEmpty && vm.filter.maxDistanceKm == 100)
        vm.clearFilters()
        #expect(vm.filterChips.isEmpty && !vm.usesLocation)
    }

    @Test func acceptedJobsAreOngoing_notHistory_forBothRoles() {
        #expect(OfferScope.active.contains(status: "Accepted"))
        #expect(!OfferScope.history.contains(status: "Accepted"))
        #expect(OfferScope.pending.contains(status: "Pending"))
        for done in ["Completed", "Rejected", "Cancelled", "Withdrawn"] {
            #expect(OfferScope.history.contains(status: done) && !OfferScope.active.contains(status: done))
        }
    }
}
