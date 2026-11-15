//
//  VerificationTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// E-posta doğrulama + şifremi unuttum (15 Kasım): kod ekranı, geri sayım, giriş ekranının 403 "email_not_verified" tepkisi. Sunucu yok.
@MainActor
struct VerificationTests {

    private func makeLogin(_ auth: FakeAuthService) -> LoginViewModel {
        let defaults = UserDefaults(suiteName: "VerificationTests-\(UUID())")!
        let vm = LoginViewModel(auth: auth, session: FakeSession(), deviceId: { "c1" }, defaults: defaults)
        vm.emailOrPhone = "ayse@x.com"; vm.password = "Abcdefg1"; vm.role = .shipper
        return vm
    }

    @Test func login_onUnverifiedEmail_opensTheCodeScreen_insteadOfAnError() async {
        let auth = FakeAuthService()
        auth.loginResult = .failure(APIError(message: "E-posta adresin henüz doğrulanmadı.", code: "email_not_verified"))
        let vm = makeLogin(auth)

        await vm.login()

        #expect(vm.errorMessage == nil)
        #expect(vm.verifyTarget?.emailOrPhone == "ayse@x.com")
        #expect(vm.verifyTarget?.role == .shipper && vm.verifyTarget?.loginAfter == true)
        #expect(vm.password == "Abcdefg1") // doğrulanınca aynı şifreyle tekrar denenecek
    }

    @Test func afterRegistration_theCodeScreenOpens_andVerifyingAsksForThePassword() async {
        let auth = FakeAuthService()
        let vm = makeLogin(auth)

        vm.registered(email: "yeni@x.com", role: .carrier)
        #expect(vm.verifyTarget?.loginAfter == false && vm.emailOrPhone == "yeni@x.com" && vm.role == .carrier && vm.password.isEmpty)

        await vm.verified(vm.verifyTarget!)
        #expect(vm.verifyTarget == nil)
        #expect(auth.loginBodies.isEmpty)       // şifre yok → otomatik giriş denenmez
        #expect(vm.infoMessage != nil)
    }

    @Test func verifyScreen_acceptsOnlySixDigits_andSendsTheRightRequest() async {
        let auth = FakeAuthService()
        let vm = VerifyEmailViewModel(target: VerifyTarget(emailOrPhone: "ayse@x.com", role: .shipper, loginAfter: true), auth: auth)

        vm.code = "12a34567"
        #expect(vm.code == "123456")             // harf atılır, en çok 6 rakam
        #expect(await vm.verify())
        #expect(auth.verifyBodies.first?.code == "123456" && auth.verifyBodies.first?.role == "Shipper")
    }

    @Test func verifyScreen_showsTheServerMessage_onAWrongCode() async {
        let auth = FakeAuthService()
        auth.verifyResult = .failure(APIError(message: "Kod hatalı ya da süresi dolmuş."))
        let vm = VerifyEmailViewModel(target: VerifyTarget(emailOrPhone: "a@x.com", role: .shipper, loginAfter: false), auth: auth)
        vm.code = "000000"

        #expect(await vm.verify() == false)
        #expect(vm.errorMessage == "Kod hatalı ya da süresi dolmuş.")
    }

    @Test func resend_isLockedFor60Seconds_thenSendsAndLocksAgain() async {
        let auth = FakeAuthService()
        var clock = Date(timeIntervalSince1970: 1_000)
        let vm = VerifyEmailViewModel(target: VerifyTarget(emailOrPhone: "a@x.com", role: .carrier, loginAfter: false), auth: auth, now: { clock })

        #expect(vm.secondsLeft() == 60)
        await vm.resend()
        #expect(auth.sentCodes.isEmpty)          // süre dolmadan gönderilmez

        clock = clock.addingTimeInterval(60)
        await vm.resend()
        #expect(auth.sentCodes.count == 1 && auth.sentCodes[0].role == "Carrier")
        #expect(vm.secondsLeft() == 60)
    }

    @Test func forgotPassword_goesToTheSecondStep_andChecksTheNewPasswordLocally() async {
        let auth = FakeAuthService()
        let vm = ForgotPasswordViewModel(emailOrPhone: " 0532 111 22 33 ", role: .shipper, auth: auth)

        await vm.sendCode()
        #expect(vm.step == .reset && auth.forgotBodies.first?.emailOrPhone == "0532 111 22 33")

        vm.code = "123456"; vm.newPassword = "YeniSifre9"; vm.confirmPassword = "Baska9999"
        #expect(await vm.reset() == false)
        #expect(vm.errorMessage == "Şifreler aynı değil.")
        #expect(auth.resetBodies.isEmpty)

        vm.confirmPassword = "YeniSifre9"
        #expect(await vm.reset())
        #expect(auth.resetBodies.first?.newPassword == "YeniSifre9")
        #expect(vm.newPassword.isEmpty)          // şifre bellekte kalmaz
    }
}
