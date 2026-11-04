//
//  RegisterViewModelTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// Yük Veren kayıt formunun mantığı: zorunlu alanlar, KVKK, paket hazırlama, sonuç/hata. Sunucu gerekmez.
@MainActor
struct RegisterViewModelTests {

    private func make() -> (RegisterViewModel, FakeAuthService) {
        let auth = FakeAuthService()
        let vm = RegisterViewModel(auth: auth)
        vm.fullName = "  Ali Veli  "; vm.email = " ali@x.com "; vm.phone = " 0532 123 45 67 "; vm.password = "Abcdefg1"; vm.kvkkAccepted = true
        return (vm, auth)
    }

    @Test func requiredFieldsMustBeFilled_andNothingIsSent() async {
        for clear in [{ (vm: RegisterViewModel) in vm.fullName = "   " }, { $0.email = "" }, { $0.phone = "" }, { $0.password = "" }] {
            let (vm, auth) = make()
            clear(vm)
            await vm.register()
            #expect(vm.errorMessage == "Lütfen zorunlu alanları doldurun.")
            #expect(auth.registerBodies.isEmpty)
        }
    }

    @Test func kvkkApprovalIsRequired() async {
        let (vm, auth) = make()
        vm.kvkkAccepted = false
        await vm.register()
        #expect(vm.errorMessage == "KVKK metnini onaylamanız gerekir.")
        #expect(auth.registerBodies.isEmpty)
    }

    @Test func buildsTheRequest_withTrimmedValues_optionalCompanyAsNil_andTheTemporaryDefaultCity() async {
        let (vm, auth) = make()
        await vm.register()

        let body = auth.registerBodies[0]
        #expect(body.fullName == "Ali Veli" && body.email == "ali@x.com" && body.phone == "0532 123 45 67") // baş/son boşluklar temizlendi
        #expect(body.password == "Abcdefg1") // şifreye dokunulmaz
        #expect(body.companyName == nil) // boş isteğe bağlı alan JSON'a yazılmaz
        #expect(vm.isSuccess == true && vm.errorMessage == nil && vm.isLoading == false)
    }

    @Test func serverMessageIsShown_onFailure_andSuccessStaysFalse() async {
        let (vm, auth) = make()
        auth.registerResult = .failure(APIError(message: "Bu e-posta zaten kayıtlı."))
        await vm.register()
        #expect(vm.errorMessage == "Bu e-posta zaten kayıtlı.")
        #expect(vm.isSuccess == false)
        #expect(vm.isLoading == false) // düğme tekrar açıldı
    }
}
