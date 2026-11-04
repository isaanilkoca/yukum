//
//  HomeViewModelTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// HomeViewModel testleri: SUNUCU ve SİMÜLATÖR GEREKMEZ. Sahte servisler verilir, ViewModel'in kararları doğrulanır.
@MainActor
struct HomeViewModelTests {

    private func make(_ user: LoginUser = Sample.carrier) -> (HomeViewModel, FakeListingService, FakeOfferService, FakeCityService) {
        let listings = FakeListingService(), offers = FakeOfferService(), cities = FakeCityService()
        return (HomeViewModel(user: user, listingService: listings, offerService: offers, cityService: cities), listings, offers, cities)
    }

    @Test func shipper_loadsOnlyTheirOwnListings_andDoesNotTouchCarrierEndpoints() async {
        let (vm, listings, offers, _) = make(Sample.shipper)
        listings.myListingsResult = .success([Sample.listing("a")])

        await vm.load(coordinate: nil)

        #expect(vm.listings.map(\.id) == ["a"])
        #expect(listings.myListingsCalls == 1)
        #expect(listings.openListingsCalls.isEmpty) // Yük Veren açık ilan listesini çağırmaz
        #expect(vm.unseenCount == 0)
        _ = offers
    }

    @Test func carrier_loadsOpenListings_withFilter_unseenBadge_andCitiesOnlyOnce() async {
        let (vm, listings, offers, cities) = make()
        listings.openListingsResult = .success([Sample.listing("x")])
        offers.unseenResult = .success(3)
        cities.citiesResult = .success([City(id: 33, name: "Mersin")])
        vm.filterCityId = 33; vm.filterDistrictId = 7

        await vm.load(coordinate: nil)
        await vm.load(coordinate: nil) // ikinci yükleme: il listesi tekrar çekilmemeli

        #expect(vm.listings.map(\.id) == ["x"])
        #expect(vm.unseenCount == 3)
        #expect(listings.openListingsCalls.last?.city == 33)
        #expect(listings.openListingsCalls.last?.district == 7)
        #expect(cities.citiesCalls == 1) // il listesi yalnız bir kez
    }

    @Test func location_isSentOnlyWhenNearMeIsOn() async {
        let (vm, listings, _, _) = make()
        let here = (latitude: 36.8, longitude: 34.6)

        await vm.load(coordinate: here) // anahtar kapalı: konum GİTMEZ
        vm.nearMe = true
        await vm.load(coordinate: here) // açık: konum gider
        await vm.load(coordinate: nil) // açık ama konum henüz yok: gitmez

        #expect(listings.openListingsCalls[0].lat == nil)
        #expect(listings.openListingsCalls[1].lat == 36.8)
        #expect(listings.openListingsCalls[1].lon == 34.6)
        #expect(listings.openListingsCalls[2].lat == nil)
    }

    @Test func apiError_showsTheServerMessage_andIsClearedByTheNextSuccessfulLoad() async {
        let (vm, listings, _, _) = make()
        listings.openListingsResult = .failure(AuthError(message: "Bu işlem için yetkiniz yok."))
        await vm.load(coordinate: nil)
        #expect(vm.listError == "Bu işlem için yetkiniz yok.")

        listings.openListingsResult = .success([])
        await vm.load(coordinate: nil)
        #expect(vm.listError == nil) // eski hata yazısı kalmaz
    }

    @Test func unknownError_showsServerUnreachable_butCancellationShowsNothing() async {
        let (vm, listings, _, _) = make()
        listings.openListingsResult = .failure(URLError(.notConnectedToInternet))
        await vm.load(coordinate: nil)
        #expect(vm.listError == "Sunucuya ulaşılamadı.")

        listings.openListingsResult = .failure(URLError(.cancelled)) // iptal hata değildir
        await vm.load(coordinate: nil)
        #expect(vm.listError == nil)
    }

    @Test func changingTheCity_resetsTheDistrict_andLoadsTheNewDistricts() async {
        let (vm, _, _, cities) = make()
        cities.districtsResult = .success([District(id: 1, name: "Mezitli")])
        vm.filterDistrictId = 99

        await vm.cityFilterChanged(to: 33)
        #expect(vm.filterDistrictId == 0) // eski ilçe sıfırlandı
        #expect(vm.filterDistricts.map(\.name) == ["Mezitli"])
        #expect(cities.districtCalls == [33])

        await vm.cityFilterChanged(to: 0) // "Tüm İller": ilçe listesi boşalır, istek yok
        #expect(vm.filterDistricts.isEmpty)
        #expect(cities.districtCalls == [33])
    }

    @Test func reloadKey_changesWithFilterNearMeAndLocation() {
        let (vm, _, _, _) = make()
        let base = vm.reloadKey(coordinate: nil)

        vm.filterCityId = 5
        let withCity = vm.reloadKey(coordinate: nil)
        vm.nearMe = true
        let withNearMe = vm.reloadKey(coordinate: nil)
        let withCoordinate = vm.reloadKey(coordinate: (36.8, 34.6))

        #expect(Set([base, withCity, withNearMe, withCoordinate]).count == 4) // her değişiklik listeyi yeniden yükletir
    }
}
