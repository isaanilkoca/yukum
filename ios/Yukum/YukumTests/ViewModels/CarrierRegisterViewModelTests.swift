//
//  CarrierRegisterViewModelTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// Taşımacı kayıt formunun mantığı: zorunlu alanlar, araç, kapasite, KVKK, iç içe paket (araç listesi), sonuç/hata. Sunucu gerekmez.
@MainActor
struct CarrierRegisterViewModelTests {

    private func make() -> (CarrierRegisterViewModel, FakeAuthService) {
        let auth = FakeAuthService()
        let vm = CarrierRegisterViewModel(auth: auth)
        vm.fullName = "Veli Nakliyat"; vm.email = "veli@x.com"; vm.phone = "0533 222 11 00"; vm.password = "Abcdefg1"
        vm.kvkkAccepted = true
        return (vm, auth)
    }

    @Test func validatesEachFieldWithItsMessage_andNothingIsSent() async {
        let cases: [(String, (CarrierRegisterViewModel) -> Void)] = [
            ("Lütfen zorunlu alanları doldurun !", { $0.email = "" }),
            ("KVKK metnini onaylamanız gerekir.", { $0.kvkkAccepted = false }),
        ]
        for (message, mutate) in cases {
            let (vm, auth) = make()
            mutate(vm)
            await vm.register()
            #expect(vm.errorMessage == message)
            #expect(auth.registerCarrierBodies.isEmpty)
        }
    }

    @Test func registrationSendsNoVehicles_andServerErrorsAreShown() async {
        // 15 Kasım: kayıtta araç sorulmuyor → paket araçsız gider (araçlar sonra Araçlarım'dan)
        let (vm, auth) = make()
        await vm.register()
        #expect(auth.registerCarrierBodies[0].vehicles == nil)
        #expect(vm.isSuccess == true)

        auth.registerCarrierResult = .failure(APIError(message: "Bu telefon zaten kayıtlı."))
        await vm.register()
        #expect(vm.errorMessage == "Bu telefon zaten kayıtlı.")
        #expect(vm.isSuccess == false)
    }
}
