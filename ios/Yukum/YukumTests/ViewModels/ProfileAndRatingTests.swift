//
//  ProfileAndRatingTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// Taşımacı profili + puan verme ViewModel'leri: sunucu gerekmez, sahte ReviewService verilir
@MainActor
struct ProfileAndRatingTests {

    // ── Profil ──
    @Test func profile_loads_andClearsTheOldErrorOnSuccess() async {
        let service = FakeReviewService()
        let vm = CarrierProfileViewModel(carrierId: "c1", service: service)

        service.profileResult = .failure(APIError(message: "Taşımacı bulunamadı."))
        await vm.load()
        #expect(vm.profile == nil)
        #expect(vm.errorMessage == "Taşımacı bulunamadı.")

        service.profileResult = .success(Sample.profile(rating: 4.5, count: 2))
        await vm.load()
        #expect(service.profileCalls == ["c1", "c1"]) // her seferinde doğru numara
        #expect(vm.profile?.fullName == "Veli Nakliyat")
        #expect(vm.errorMessage == nil)
        #expect(!vm.isLoading)
    }

    @Test func ratingText_showsStarsOnlyWhenSomeoneRated() {
        #expect(RatingText.summary(rating: 0, count: 0) == "Yeni")
        #expect(RatingText.summary(rating: 4.5, count: 8) == "★ 4.5 (8)")
        #expect(RatingText.summary(rating: 3.333, count: 3) == "★ 3.3 (3)") // tek basamak
    }

    // ── Puan verme ──
    @Test func submit_sendsTheRating_withTrimmedComment_orNilWhenEmpty() async {
        let service = FakeReviewService()
        let vm = RatingViewModel(offerId: "o1", carrierName: "Veli", service: service)
        vm.rating = 4; vm.comment = "  Güzel iş  "

        #expect(await vm.submit())
        #expect(service.createCalls.last?.offerId == "o1")
        #expect(service.createCalls.last?.body.rating == 4)
        #expect(service.createCalls.last?.body.comment == "Güzel iş")

        vm.comment = "   "
        #expect(await vm.submit())
        #expect(service.createCalls.last?.body.comment == nil) // boş yorum gönderilmez
    }

    @Test func submit_rejectsInvalidInput_withoutCallingTheServer() async {
        let service = FakeReviewService()
        let vm = RatingViewModel(offerId: "o1", carrierName: "Veli", service: service)

        vm.rating = 0
        #expect(await vm.submit() == false)
        vm.rating = 6
        #expect(await vm.submit() == false)
        vm.rating = 5; vm.comment = String(repeating: "x", count: 501)
        #expect(await vm.submit() == false)
        #expect(vm.errorMessage != nil)
        #expect(service.createCalls.isEmpty)
    }

    @Test func submit_failureShowsTheServerMessage_andKeepsTheSheetOpen() async {
        let service = FakeReviewService()
        service.createResult = .failure(APIError(message: "Bu iş için zaten puan verdin."))
        let vm = RatingViewModel(offerId: "o1", carrierName: "Veli", service: service)

        #expect(await vm.submit() == false)
        #expect(vm.errorMessage == "Bu iş için zaten puan verdin.")
        #expect(!vm.isSending)
    }

    // ── Puan ver / profil düğmeleri ──
    @Test func oldOffers_canRateOnlyCompletedAndNotYetReviewedJobs() {
        let vm = OldOffersViewModel(service: FakeOfferService())
        #expect(vm.canRate(Sample.historyOffer(status: "Completed", reviewed: false)))
        #expect(!vm.canRate(Sample.historyOffer(status: "Completed", reviewed: true))) // zaten puanlanmış
        #expect(!vm.canRate(Sample.historyOffer(status: "Accepted"))) // iş bitmedi
        #expect(!vm.canRate(Sample.historyOffer(status: "Rejected")))
    }

    @Test func onlyTheShipperHistoryChatOffersTheRatingSheet() {
        #expect(ChatContext.forShipperHistory(Sample.historyOffer(status: "Accepted", stage: "Delivered")).canReview)
        #expect(!ChatContext.forCarrier(Sample.carrierOffer(status: "Accepted", stage: "Delivered")).canReview)
        #expect(!ChatContext.forShipperPending(Sample.listingOffer()).canReview)
    }
}
