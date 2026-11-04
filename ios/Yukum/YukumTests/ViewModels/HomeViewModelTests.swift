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
        let (vm, listings, offers, cities, _, _) = makeAll(user)
        return (vm, listings, offers, cities)
    }

    // makeAll: konum ve oturum sahteleriyle birlikte
    private func makeAll(_ user: LoginUser = Sample.carrier) -> (HomeViewModel, FakeListingService, FakeOfferService, FakeCityService, FakeLocation, FakeSession) {
        let listings = FakeListingService(), offers = FakeOfferService(), cities = FakeCityService(), location = FakeLocation(), session = FakeSession()
        let vm = HomeViewModel(user: user, listingService: listings, offerService: offers, cityService: cities, session: session, location: location)
        return (vm, listings, offers, cities, location, session)
    }

    @Test func shipper_loadsOnlyTheirOwnListings_andDoesNotTouchCarrierEndpoints() async {
        let (vm, listings, offers, _) = make(Sample.shipper)
        listings.myListingsResult = .success([Sample.listing("a")])

        await vm.load()

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

        await vm.load()
        await vm.load() // ikinci yükleme: il listesi tekrar çekilmemeli

        #expect(vm.listings.map(\.id) == ["x"])
        #expect(vm.unseenCount == 3)
        #expect(listings.openListingsCalls.last?.city == 33)
        #expect(listings.openListingsCalls.last?.district == 7)
        #expect(cities.citiesCalls == 1) // il listesi yalnız bir kez
    }

    @Test func location_isSentOnlyWhenNearMeIsOn_andOnlyOnceItIsFound() async {
        let (vm, listings, _, _, location, _) = makeAll()
        location.latitude = 36.8; location.longitude = 34.6

        await vm.load() // anahtar kapalı: konum GİTMEZ
        vm.nearMe = true
        await vm.load() // açık: konum gider
        location.latitude = nil; location.longitude = nil
        await vm.load() // açık ama konum henüz yok: gitmez

        #expect(listings.openListingsCalls[0].lat == nil)
        #expect(listings.openListingsCalls[1].lat == 36.8)
        #expect(listings.openListingsCalls[1].lon == 34.6)
        #expect(listings.openListingsCalls[2].lat == nil)
    }

    @Test func nearMeChanged_asksForLocationOnlyWhenTurnedOn() {
        let (vm, _, _, _, location, _) = makeAll()
        vm.nearMeChanged(to: false)
        #expect(location.requestCalls == 0)
        vm.nearMeChanged(to: true)
        #expect(location.requestCalls == 1) // izin penceresi / konum isteği tetiklendi
    }

    @Test func locationProblems_areExposedOnlyWhileNearMeIsOn() {
        let (vm, _, _, _, location, _) = makeAll()
        location.isDenied = true
        #expect(vm.isLocationDenied == false) // anahtar kapalıyken izin uyarısı yok
        vm.nearMe = true
        #expect(vm.isLocationDenied == true) // reddedildi → "Ayarları aç" satırı
        #expect(vm.locationError == nil) // izin reddedildiğinde ayrı hata yazısı çıkmaz

        location.isDenied = false; location.errorMessage = "Konum alınamadı"
        #expect(vm.isLocationDenied == false)
        #expect(vm.locationError == "Konum alınamadı")
    }

    @Test func signOut_callsTheSession() async {
        let (vm, _, _, _, _, session) = makeAll()
        await vm.signOut()
        #expect(session.signOutCalls == 1)
    }

    @Test func apiError_showsTheServerMessage_andIsClearedByTheNextSuccessfulLoad() async {
        let (vm, listings, _, _) = make()
        listings.openListingsResult = .failure(APIError(message: "Bu işlem için yetkiniz yok."))
        await vm.load()
        #expect(vm.listError == "Bu işlem için yetkiniz yok.")

        listings.openListingsResult = .success([])
        await vm.load()
        #expect(vm.listError == nil) // eski hata yazısı kalmaz
    }

    @Test func unknownError_showsServerUnreachable_butCancellationShowsNothing() async {
        let (vm, listings, _, _) = make()
        listings.openListingsResult = .failure(URLError(.notConnectedToInternet))
        await vm.load()
        #expect(vm.listError == "Sunucuya ulaşılamadı.")

        listings.openListingsResult = .failure(URLError(.cancelled)) // iptal hata değildir
        await vm.load()
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
        let (vm, _, _, _, location, _) = makeAll()
        let base = vm.reloadKey

        vm.filterCityId = 5
        let withCity = vm.reloadKey
        vm.nearMe = true
        let withNearMe = vm.reloadKey
        location.latitude = 36.8; location.longitude = 34.6
        let withCoordinate = vm.reloadKey

        #expect(Set([base, withCity, withNearMe, withCoordinate]).count == 4) // her değişiklik listeyi yeniden yükletir
    }
}
