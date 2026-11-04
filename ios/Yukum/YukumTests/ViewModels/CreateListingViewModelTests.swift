//
//  CreateListingViewModelTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// "İlan Ver" formunun mantığı: alan doğrulama, il→ilçe zinciri, paket hazırlama. Sunucu gerekmez.
@MainActor
struct CreateListingViewModelTests {

    private func listingVM() -> (CreateListingViewModel, FakeListingService, FakeCityService) {
        let listings = FakeListingService(), cities = FakeCityService()
        let vm = CreateListingViewModel(listingService: listings, cityService: cities)
        vm.title = "  20 palet  "; vm.weightKg = "1000"; vm.vehicleType = "Truck"
        vm.fromCityId = 33; vm.fromDistrictId = 1; vm.toCityId = 34; vm.toDistrictId = 2
        return (vm, listings, cities)
    }

    @Test func listing_validatesEachFieldWithItsMessage() async {
        let cases: [(String, (CreateListingViewModel) -> Void)] = [
            ("Başlığı Giriniz !", { $0.title = "  " }),
            ("Ağırlık sayı olmalı", { $0.weightKg = "abc" }),
            ("Ağırlık en fazla 1.000.000 kg olabilir.", { $0.weightKg = "5000000" }),
            ("Araç türünü seçiniz", { $0.vehicleType = "" }),
            ("Kalkış ve varış il-ilçesini seçiniz", { $0.toDistrictId = 0 }),
            ("Bütçe sayı olmalı", { $0.budget = "abc" }),
            ("Bütçe 1 ile 100.000.000 ₺ arasında olmalı.", { $0.budget = "123123123122" }),
        ]
        for (message, mutate) in cases {
            let (vm, listings, _) = listingVM()
            mutate(vm)
            #expect(await vm.submit() == false)
            #expect(vm.errorMessage == message)
            #expect(listings.createBodies.isEmpty) // geçersiz form sunucuya gitmez
        }
    }

    @Test func listing_buildsTheRequest_withTrimmedTitle_nilOptionals_andTheApiDateFormat() async {
        let (vm, listings, _) = listingVM()
        vm.pickupDate = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 12))!

        #expect(await vm.submit() == true)

        let body = listings.createBodies[0]
        #expect(body.title == "20 palet") // baş/son boşluk temizlendi
        #expect(body.description == nil && body.budget == nil) // boş isteğe bağlı alanlar JSON'a yazılmaz
        #expect(body.pickupDate == "2026-11-05")
        #expect(body.weightKg == 1000 && body.fromCityId == 33 && body.toDistrictId == 2)
    }

    @Test func listing_serverMessageIsShown_onFailure() async {
        let (vm, listings, _) = listingVM()
        listings.createResult = .failure(APIError(message: "Kalkış ilçesi seçilen ile ait değil."))
        #expect(await vm.submit() == false)
        #expect(vm.errorMessage == "Kalkış ilçesi seçilen ile ait değil.")
        #expect(vm.isLoading == false)
    }

    @Test func listing_changingACityResetsItsDistrict_andLoadsTheNewOnes() async {
        let (vm, _, cities) = listingVM()
        cities.districtsResult = .success([District(id: 7, name: "Çankaya")])

        await vm.fromCityChanged(to: 6)

        #expect(vm.fromDistrictId == 0) // eski ilçe sıfırlandı
        #expect(vm.fromDistricts.map(\.name) == ["Çankaya"])
        #expect(vm.toDistrictId == 2) // varış etkilenmez
        await vm.toCityChanged(to: 0)
        #expect(vm.toDistricts.isEmpty)
    }

    @Test func listing_loadsTheCitiesOnlyOnce() async {
        let (vm, _, cities) = listingVM()
        cities.citiesResult = .success([City(id: 1, name: "Adana")])
        await vm.loadCities(); await vm.loadCities()
        #expect(cities.citiesCalls == 1)
    }
}
