//
//  ProfilePageTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// 8. adım (15 Kasım): profil sayfası verileri, İlanlarım rozetleri, Yük Veren profili, üyelik tarihi yazısı. Sunucu yok, sahte servisler.
@MainActor
struct ProfilePageTests {

    @Test func home_loadMe_fillsThePhotoSource_andSyncsTheGreetingName() async {
        let account = FakeAccountService()
        account.profileResult = .success(FakeAccountService.sampleProfile.with(avatarUrl: "/api/v1/avatars/a1"))
        let vm = HomeViewModel(user: Sample.shipper, listingService: FakeListingService(), offerService: FakeOfferService(),
                               cityService: FakeCityService(), session: FakeSession(), location: FakeLocation(), accountService: account)

        await vm.loadMe()

        #expect(vm.me?.avatarUrl == "/api/v1/avatars/a1")
        #expect(vm.user.displayName == "Ali Veli") // sunucudaki ad selamlamaya yansır (başka cihazda değiştirildiyse de)
    }

    @Test func myListings_loadsAllStatuses_andMapsBadges() async {
        let service = FakeListingService()
        var closed = Sample.listing("b"); closed.status = "Cancelled"
        service.allMyListingsResult = .success([Sample.listing("a"), closed])
        let vm = MyListingsViewModel(service: service)

        await vm.load()

        #expect(vm.listings.count == 2 && vm.loaded)
        #expect(MyListingsViewModel.badge(for: "Cancelled").text == "Kaldırıldı")
        #expect(MyListingsViewModel.badge(for: "Completed").tone == .success)
        #expect(MyListingsViewModel.badge(for: nil).text == "Yayında") // eski cevap (durum yok) → açık sayılır
    }

    @Test func shipperProfile_loads_orShowsTheServerMessage() async {
        let reviews = FakeReviewService()
        let vm = ShipperProfileViewModel(shipperId: "s1", service: reviews)
        await vm.load()
        #expect(vm.profile?.companyName == "Kaya Gıda")
        #expect(reviews.profileCalls == ["s1"])

        reviews.shipperProfileResult = .failure(APIError(message: "Yük Veren bulunamadı."))
        await vm.load()
        #expect(vm.errorMessage == "Yük Veren bulunamadı.")
    }

    @Test func memberSince_readsServerDates_andHidesTheEmptyDefault() {
        #expect(MemberSince.text("2026-03-01T10:00:00Z") == "Mart 2026")
        #expect(MemberSince.text("2026-11-15T21:57:36.1234567") == "Kasım 2026") // SQL DateTime: saat dilimsiz, 7 hane kesir
        #expect(MemberSince.text("0001-01-01T00:00:00") == nil)                 // varsayılan tarih gösterilmez
        #expect(MemberSince.text(nil) == nil)
    }
}
