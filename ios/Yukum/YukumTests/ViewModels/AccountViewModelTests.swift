//
//  AccountViewModelTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// Hesap silme ViewModel'i: sunucu gerekmez, sahte servis + sahte oturum verilir
@MainActor
struct AccountViewModelTests {

    private func make() -> (AccountViewModel, FakeAccountService, FakeSession) {
        let service = FakeAccountService(), session = FakeSession()
        return (AccountViewModel(service: service, session: session), service, session)
    }

    @Test func emptyPassword_isRefused_withoutCallingTheServer() async {
        let (vm, service, session) = make()

        #expect(await vm.deleteAccount() == false)

        #expect(vm.errorMessage == "Hesabı silmek için şifreni gir.")
        #expect(service.deleteCalls.isEmpty)
        #expect(session.signOutCalls == 0) // oturum açık kalır
    }

    @Test func success_sendsThePassword_signsOutLocally_andClearsThePassword() async {
        let (vm, service, session) = make()
        vm.password = "Abcdefg1"

        #expect(await vm.deleteAccount() == true)

        #expect(service.deleteCalls.first?.password == "Abcdefg1")
        #expect(session.signOutCalls == 1) // yerel oturum silindi (Keychain + bellek)
        #expect(vm.password.isEmpty) // şifre bellekte kalmaz
        #expect(vm.errorMessage == nil)
        #expect(vm.isDeleting == false)
    }

    @Test func serverRefusal_showsTheMessage_andKeepsTheSession() async {
        let (vm, service, session) = make()
        service.deleteResult = .failure(APIError(message: "Şifre hatalı."))
        vm.password = "yanlis"

        #expect(await vm.deleteAccount() == false)

        #expect(vm.errorMessage == "Şifre hatalı.")
        #expect(session.signOutCalls == 0) // hesap silinmedi: oturum SÜRER (kullanıcı çıkış yapmaya zorlanmaz)
        #expect(vm.password == "yanlis") // kullanıcı düzeltip tekrar deneyebilir
        #expect(vm.isDeleting == false)
    }

    @Test func activeJobConflict_showsTheServerExplanation() async {
        let (vm, service, _) = make()
        service.deleteResult = .failure(APIError(message: "Devam eden bir işin var. Önce işi tamamla ya da ilanı iptal et, sonra hesabını silebilirsin."))
        vm.password = "Abcdefg1"

        #expect(await vm.deleteAccount() == false)
        #expect(vm.errorMessage?.hasPrefix("Devam eden bir işin var") == true)
    }
}
