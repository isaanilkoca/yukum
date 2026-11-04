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
        vm.vehicleType = VehicleType.truck.rawValue; vm.capacityKg = "24000"; vm.kvkkAccepted = true
        return (vm, auth)
    }

    @Test func validatesEachFieldWithItsMessage_andNothingIsSent() async {
        let cases: [(String, (CarrierRegisterViewModel) -> Void)] = [
            ("Lütfen zorunlu alanları doldurun !", { $0.email = "" }),
            ("Araç türünü seçiniz !", { $0.vehicleType = "" }),
            ("Kapasite sayı olmalı.", { $0.capacityKg = "abc" }),
            ("Kapasite sıfırdan büyük olmalı.", { $0.capacityKg = "0" }),
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

    @Test func buildsTheNestedRequest_withOneVehicleInside() async {
        let (vm, auth) = make()
        vm.plateNumber = "33 ABC 123"

        await vm.register()

        let body = auth.registerCarrierBodies[0]
        #expect(body.vehicles.count == 1) // araç, kayıt paketinin İÇİNDE liste olarak gider
        #expect(body.vehicles[0].type == "Truck" && body.vehicles[0].capacityKg == 24000 && body.vehicles[0].plateNumber == "33 ABC 123")
        #expect(body.homeCityId == CarrierRegisterViewModel.defaultCityId)
        #expect(vm.isSuccess == true)
    }

    @Test func emptyPlateIsSentAsNil_andServerErrorsAreShown() async {
        let (vm, auth) = make()
        await vm.register()
        #expect(auth.registerCarrierBodies[0].vehicles[0].plateNumber == nil)

        auth.registerCarrierResult = .failure(APIError(message: "Bu telefon zaten kayıtlı."))
        await vm.register()
        #expect(vm.errorMessage == "Bu telefon zaten kayıtlı.")
        #expect(vm.isSuccess == false)
    }
}
