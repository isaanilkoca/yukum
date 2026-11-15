//
//  AccountInfoViewModelTests.swift
//  YukumTests
//

import Testing
import Foundation
import UIKit
@testable import Yukum

// Hesap Bilgilerim (15 Kasım): sunucu yok; sahte hesap + il servisi. Sınanan: formun dolması, telefon değişince şifre şartı,
// gönderilen paket, hata mesajı, fotoğrafın 512 px JPEG'e küçültülmesi.
@MainActor
struct AccountInfoViewModelTests {

    private func make() async -> (AccountInfoViewModel, FakeAccountService) {
        let service = FakeAccountService(), cities = FakeCityService()
        cities.citiesResult = .success([City(id: 33, name: "Mersin"), City(id: 34, name: "İstanbul")])
        let vm = AccountInfoViewModel(service: service, cityService: cities)
        await vm.load()
        return (vm, service)
    }

    @Test func load_fillsTheForm_andShowsThePhoneReadably() async {
        let (vm, _) = await make()
        #expect(vm.fullName == "Ali Veli")
        #expect(vm.phone == "0532 123 45 67")
        #expect(vm.cityId == 33)
        #expect(vm.cities.count == 2)
        #expect(vm.hasChanges == false) // yeni yüklenen form "değişmedi" sayılır → Kaydet kapalı
    }

    @Test func sameNumberInAnotherFormat_isNotAPhoneChange() async {
        let (vm, _) = await make()
        vm.phone = "+90 532 123 4567"
        #expect(vm.phoneChanged == false)
    }

    @Test func phoneChange_withoutPassword_isRefusedWithoutCallingTheServer() async {
        let (vm, service) = await make()
        vm.phone = "0533 000 00 00"

        #expect(vm.phoneChanged)
        #expect(await vm.save() == false)
        #expect(vm.errorMessage == "Telefonu değiştirmek için mevcut şifreni gir.")
        #expect(service.updateCalls.isEmpty)
    }

    @Test func phoneChange_sendsThePassword_thenClearsIt() async {
        let (vm, service) = await make()
        vm.phone = "0533 000 00 00"
        vm.currentPassword = "Abcdefg1"

        #expect(await vm.save())
        #expect(service.updateCalls.first?.currentPassword == "Abcdefg1")
        #expect(service.updateCalls.first?.phone == "5330000000")
        #expect(vm.currentPassword.isEmpty)    // şifre bellekte kalmaz
        #expect(vm.phoneChanged == false)      // sunucunun döndürdüğü yeni numara artık "mevcut"
    }

    @Test func nameChange_sendsNoPassword_andEmptyTextBecomesNil() async {
        let (vm, service) = await make()
        vm.fullName = "  Ali Yılmaz "
        vm.about = "   "

        #expect(vm.hasChanges)
        #expect(await vm.save())
        let sent = service.updateCalls.first
        #expect(sent?.fullName == "Ali Yılmaz")
        #expect(sent?.currentPassword == nil)
        #expect(sent?.about == nil)
    }

    @Test func serverRefusal_showsTheServerMessage() async {
        let (vm, service) = await make()
        service.updateResult = .failure(APIError(message: "Bu telefon numarasıyla zaten bir hesap var."))
        vm.phone = "0533 000 00 00"; vm.currentPassword = "Abcdefg1"

        #expect(await vm.save() == false)
        #expect(vm.errorMessage == "Bu telefon numarasıyla zaten bir hesap var.")
    }

    @Test func photo_isShrunkToA512SquareJpeg_beforeUpload() async {
        let (vm, service) = await make()
        // 1200×800 kırmızı PNG (yatay): kısa kenardan kare kırpılıp 512×512 olmalı
        let big = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 800)).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 800))
        }.pngData()!

        await vm.uploadAvatar(big)

        let sent = try! #require(service.uploadCalls.first)
        #expect(Array(sent.prefix(3)) == [0xFF, 0xD8, 0xFF]) // JPEG imzası (sunucu bunu denetler: AvatarImage.Detect)
        let image = UIImage(data: sent)!
        #expect(image.size.width == 512 && image.size.height == 512)
        #expect(vm.profile?.avatarUrl == "/api/v1/avatars/yeni")
    }

    @Test func notAnImage_isNotUploaded() async {
        let (vm, service) = await make()
        await vm.uploadAvatar(Data("metin".utf8))
        #expect(service.uploadCalls.isEmpty)
        #expect(vm.errorMessage == "Fotoğraf okunamadı.")
    }
}
