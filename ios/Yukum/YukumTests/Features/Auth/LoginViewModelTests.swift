//
//  LoginViewModelTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// Giriş ekranının mantığı: doğrulama, sabit cihaz kimliği, otomatik giriş, hata. Sunucu gerekmez.
@MainActor
struct LoginViewModelTests {

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
        auth.loginResult = .failure(APIError(message: "E-posta veya şifre hatalı."))
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
        session2.result = .failure(APIError(message: "Oturum süresi doldu.", isSessionExpired: true))
        await vm2.restoreSession()
        #expect(vm2.loggedInUser == nil) // oturum geçersiz → giriş formu
        #expect(vm2.isRestoring == false) // çark kapanır
    }
}
