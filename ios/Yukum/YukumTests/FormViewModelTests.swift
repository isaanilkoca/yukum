//
//  FormViewModelTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// Giriş, teklif formu ve ilan formu mantığı: doğrulama, paket hazırlama, hata/başarı. Sunucu gerekmez.
@MainActor
struct FormViewModelTests {

    // ─── Giriş ───
    private func loginVM() -> (LoginViewModel, FakeAuthService, FakeSession) {
        let auth = FakeAuthService(), session = FakeSession()
        return (LoginViewModel(auth: auth, session: session, deviceId: { "cihaz-1" }), auth, session)
    }

    @Test func login_requiresBothFields_andDoesNotCallTheServer() async {
        let (vm, auth, _) = loginVM()
        vm.emailOrPhone = "ali@x.com"
        await vm.login()
        #expect(vm.errorMessage == "E-posta/telefon ve şifre gerekli.")
        #expect(auth.loginBodies.isEmpty)
    }

    @Test func login_sendsTrimmedIdentity_andTheStableDeviceId_thenSetsTheUserAndClearsThePassword() async {
        let (vm, auth, _) = loginVM()
        auth.loginResult = .success(LoginResponse(accessToken: "a", refreshToken: "r", user: Sample.carrier))
        vm.emailOrPhone = "  ali@x.com "; vm.password = "Abcdefg1"

        await vm.login()

        #expect(auth.loginBodies.first?.emailOrPhone == "ali@x.com") // baş/son boşluk temizlendi
        #expect(auth.loginBodies.first?.deviceId == "cihaz-1") // sabit cihaz kimliği
        #expect(vm.loggedInUser?.role == "Carrier")
        #expect(vm.password.isEmpty) // şifre bellekte kalmaz
        #expect(vm.isLoading == false)
    }

    @Test func login_showsTheServerMessage_andStaysOnTheForm() async {
        let (vm, auth, _) = loginVM()
        auth.loginResult = .failure(AuthError(message: "E-posta veya şifre hatalı."))
        vm.emailOrPhone = "ali@x.com"; vm.password = "yanlis"

        await vm.login()

        #expect(vm.errorMessage == "E-posta veya şifre hatalı.")
        #expect(vm.loggedInUser == nil)
        #expect(vm.isLoading == false) // düğme tekrar açıldı
    }

    @Test func restoreSession_logsTheUserInAutomatically_orFallsBackToTheForm() async {
        let (vm, _, session) = loginVM()
        session.result = .success(Sample.shipper)
        await vm.restoreSession()
        #expect(vm.loggedInUser?.id == "s1")
        #expect(vm.isRestoring == false)

        let (vm2, _, session2) = loginVM()
        session2.result = .failure(AuthError(message: "Oturum süresi doldu.", isSessionExpired: true))
        await vm2.restoreSession()
        #expect(vm2.loggedInUser == nil) // oturum geçersiz → giriş formu
        #expect(vm2.isRestoring == false) // çark kapanır
    }

    // ─── Teklif formu ───
    private func offerVM(myOffer: Double? = nil) -> (OfferFormViewModel, FakeOfferService) {
        let service = FakeOfferService()
        let base = Sample.listing("L1")
        let listing = Listing(id: base.id, title: base.title, weightKg: base.weightKg, fromCityName: base.fromCityName, fromDistrictName: base.fromDistrictName,
                              toCityName: base.toCityName, toDistrictName: base.toDistrictName, pickupDate: base.pickupDate, budget: base.budget,
                              myOfferAmount: myOffer, myOfferStatus: nil, distanceKm: nil)
        return (OfferFormViewModel(listing: listing, service: service), service)
    }

    @Test func offer_rejectsInvalidAmounts_withoutCallingTheServer() async {
        let (vm, service) = offerVM()
        for bad in ["", "abc", "0", "-5", "123123123122"] { // boş, harf, sıfır, eksi, sunucu sınırının üstü
            vm.amountText = bad
            #expect(await vm.submit() == false)
            #expect(vm.errorMessage != nil)
        }
        #expect(service.createCalls.isEmpty)
    }

    @Test func offer_sendsAmountAndTrimmedNote_andReturnsTrue() async {
        let (vm, service) = offerVM()
        vm.amountText = " 1200 "; vm.note = "  yarın yüklerim  "

        #expect(await vm.submit() == true)

        #expect(service.createCalls.first?.listingId == "L1")
        #expect(service.createCalls.first?.body.amount == 1200)
        #expect(service.createCalls.first?.body.note == "yarın yüklerim")
    }

    @Test func offer_emptyNoteIsSentAsNil_andServerErrorsAreShown() async {
        let (vm, service) = offerVM()
        vm.amountText = "500"; vm.note = "   "
        _ = await vm.submit()
        #expect(service.createCalls.first?.body.note == nil)

        service.createResult = .failure(AuthError(message: "Bu ilan artık teklif almıyor."))
        #expect(await vm.submit() == false)
        #expect(vm.errorMessage == "Bu ilan artık teklif almıyor.")
    }

    @Test func offer_buttonSaysUpdateWhenAnOfferAlreadyExists() {
        #expect(offerVM().0.buttonTitle == "Teklifi Gönder")
        #expect(offerVM(myOffer: 900).0.buttonTitle == "Teklifi Güncelle")
    }

    // ─── İlan formu ───
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
        listings.createResult = .failure(AuthError(message: "Kalkış ilçesi seçilen ile ait değil."))
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
