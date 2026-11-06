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

    // ---------- düzenleme modu ----------
    private func editVM() -> (CreateListingViewModel, FakeListingService, FakeCityService) {
        let listings = FakeListingService(), cities = FakeCityService()
        let vm = CreateListingViewModel(editing: Sample.listing("L9", title: "Eski başlık"), listingService: listings, cityService: cities)
        return (vm, listings, cities)
    }

    @Test func newListing_isNotInEditMode_andKeepsTheCreateTitles() {
        let vm = CreateListingViewModel(listingService: FakeListingService(), cityService: FakeCityService())
        #expect(vm.isEditing == false && vm.screenTitle == "İlan Ver" && vm.submitTitle == "İlanı Yayınla")
        #expect(vm.cities.isEmpty && vm.fromDistricts.isEmpty) // yeni ilanda başlangıç listesi yok
    }

    @Test func editing_prefillsTheFormFromTheListing() {
        let (vm, _, _) = editVM()
        #expect(vm.isEditing == true && vm.screenTitle == "İlanı Düzenle" && vm.submitTitle == "İlanı Güncelle")
        #expect(vm.title == "Eski başlık" && vm.details == "" && vm.weightKg == "1000" && vm.vehicleType == "Truck")
        #expect(vm.budget == "5000") // API Double (5000.0) verir, forma tam sayı yazısı konur
        #expect(vm.fromCityId == 33 && vm.fromDistrictId == 1 && vm.toCityId == 34 && vm.toDistrictId == 2)
        #expect(CreateListingViewModel.formatDate(vm.pickupDate) == "2026-12-01")
    }

    @Test func editing_startsWithListsThatContainTheSelection_soPickersAreValidAtFirstDraw() {
        let (vm, _, _) = editVM()
        #expect(Set(vm.cities.map(\.id)) == [33, 34])
        #expect(vm.fromDistricts.map(\.id) == [1] && vm.toDistricts.map(\.id) == [2])
        #expect(vm.cities.map(\.name).contains("Mersin") && vm.fromDistricts.map(\.name) == ["Mezitli"]) // adlar Listing'ten
    }

    @Test func editing_loadCitiesFetchesTheFullLists_withoutResettingTheSavedDistricts() async {
        let (vm, _, cities) = editVM()
        cities.citiesResult = .success([City(id: 6, name: "Ankara"), City(id: 33, name: "Mersin"), City(id: 34, name: "İstanbul")])
        cities.districtsResult = .success([District(id: 1, name: "Mezitli"), District(id: 2, name: "Kadıköy"), District(id: 3, name: "Çankaya")])

        await vm.loadCities()

        #expect(vm.cities.count == 3)
        #expect(cities.districtCalls == [33, 34]) // kalkış ve varış illerinin ilçeleri çekildi
        #expect(vm.fromDistricts.count == 3 && vm.toDistricts.count == 3)
        #expect(vm.fromDistrictId == 1 && vm.toDistrictId == 2) // kayıtlı seçimler sıfırlanmadı
    }

    @Test func editing_loadCitiesFailureKeepsTheSeededLists_andRetriesNextTime() async {
        let (vm, _, cities) = editVM()
        cities.citiesResult = .failure(StubError())

        await vm.loadCities()
        #expect(Set(vm.cities.map(\.id)) == [33, 34]) // başlangıç listesi bozulmadı, Picker geçerli kaldı
        #expect(vm.fromDistrictId == 1)

        await vm.loadCities()
        #expect(cities.citiesCalls == 2) // başarısızlıktan sonra yeniden denendi (bayrak kalkmamıştı)
    }

    @Test func editing_submitCallsUpdateWithTheListingId_notCreate() async {
        let (vm, listings, _) = editVM()
        vm.title = "  Yeni başlık "; vm.weightKg = "2000"

        #expect(await vm.submit() == true)

        #expect(listings.createBodies.isEmpty) // yeni ilan açılmadı
        #expect(listings.updateCalls.count == 1)
        #expect(listings.updateCalls[0].id == "L9")
        let body = listings.updateCalls[0].body
        #expect(body.title == "Yeni başlık" && body.weightKg == 2000) // değişen alanlar gitti, başlık kırpıldı
        #expect(body.fromCityId == 33 && body.toDistrictId == 2 && body.budget == 5000 && body.pickupDate == "2026-12-01") // dokunulmayanlar aynı
    }

    @Test func editing_serverRefusalIsShown_andTheFormStaysOpen() async {
        let (vm, listings, _) = editVM()
        listings.updateResult = .failure(APIError(message: "Teklif kabul edilmiş ilan güncellenemez."))

        #expect(await vm.submit() == false)

        #expect(vm.errorMessage == "Teklif kabul edilmiş ilan güncellenemez.")
        #expect(vm.isLoading == false)
        #expect(listings.createBodies.isEmpty)
    }

    @Test func editing_stillValidatesBeforeCallingTheServer() async {
        let (vm, listings, _) = editVM()
        vm.title = "  "
        #expect(await vm.submit() == false)
        #expect(vm.errorMessage == "Başlığı Giriniz !")
        #expect(listings.updateCalls.isEmpty)
    }

    @Test func dateText_roundTrips_andInvalidTextGivesNil() {
        let date = CreateListingViewModel.parseDate("2026-12-01")
        #expect(date != nil && CreateListingViewModel.formatDate(date!) == "2026-12-01")
        #expect(CreateListingViewModel.parseDate("yarın") == nil)
    }
}
