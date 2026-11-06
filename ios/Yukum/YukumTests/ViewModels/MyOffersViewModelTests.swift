//
//  MyOffersViewModelTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// "Tekliflerim" (Taşımacı) ekranının mantığı: bölümler, silme kuralları, "görüldü", sohbet bilgisi, hata/iptal. Sunucu gerekmez.
@MainActor
struct MyOffersViewModelTests {

    @Test func myOffers_splitIntoPendingAndHistory() async {
        let service = FakeOfferService()
        service.myOffersResult = .success([Sample.carrierOffer("a", status: "Pending"), Sample.carrierOffer("b", status: "Accepted"),
                                           Sample.carrierOffer("c", status: "Rejected")])
        let vm = MyOffersViewModel(service: service)

        await vm.load()

        #expect(vm.pendingOffers.map(\.id) == ["a"])
        #expect(vm.historyOffers.map(\.id) == ["b", "c"]) // kabul/red/tamamlanan/iptal "geçmiş" bölümünde
    }

    @Test func myOffers_onlyFinishedOffersCanBeHidden() {
        let vm = MyOffersViewModel(service: FakeOfferService())
        for status in ["Rejected", "Completed", "Cancelled"] { #expect(vm.canHide(Sample.carrierOffer(status: status))) }
        for status in ["Pending", "Accepted"] { #expect(!vm.canHide(Sample.carrierOffer(status: status))) } // bekleyen: karar yok, kabul: aktif iş
        #expect(!vm.canChat(Sample.carrierOffer(status: "Rejected"))) // reddedilende sohbet yok
        #expect(vm.canChat(Sample.carrierOffer(status: "Completed")))
    }

    @Test func myOffers_loadAndMarkSeen_loadsFirstThenMarksSeen() async {
        let service = FakeOfferService()
        service.myOffersResult = .success([Sample.carrierOffer(isNew: true)])
        let vm = MyOffersViewModel(service: service)

        await vm.loadAndMarkSeen()

        #expect(vm.offers.first?.isNew == true) // "Yeni" rozeti listede çizilebilir
        #expect(service.markSeenCalls == 1) // sonra görüldü işaretlendi
    }

    @Test func myOffers_hideCallsTheServer_thenReloads_andShowsAnErrorIfRejected() async {
        let service = FakeOfferService()
        let vm = MyOffersViewModel(service: service)
        await vm.hide(Sample.carrierOffer("x", status: "Rejected"))
        #expect(service.hiddenIds == ["x"])
        #expect(vm.errorMessage == nil)

        service.hideResult = .failure(APIError(message: "Kabul edilmiş teklif aktif iştir."))
        await vm.hide(Sample.carrierOffer("y", status: "Accepted"))
        #expect(vm.errorMessage == "Kabul edilmiş teklif aktif iştir.")
    }

    @Test func myOffers_openChatBuildsTheCarrierContext() {
        let vm = MyOffersViewModel(service: FakeOfferService())
        vm.openChat(Sample.carrierOffer("o9", status: "Accepted", stage: "Delivered"))
        #expect(vm.chat?.offerId == "o9")
        #expect(vm.chat?.canComplete == true)
    }

    @Test func aCancelledRequest_isNotShownAsAnError() async {
        let service = FakeOfferService()
        service.myOffersResult = .failure(URLError(.cancelled))
        let vm = MyOffersViewModel(service: service)

        await vm.load()

        #expect(vm.errorMessage == nil) // iptal hata değildir
    }

    @Test func withdraw_isOnlyForPendingOffers_andWithdrawnOnesAreDeletableButHaveNoChat() {
        let vm = MyOffersViewModel(service: FakeOfferService())
        #expect(vm.canWithdraw(Sample.carrierOffer(status: "Pending")))
        for status in ["Accepted", "Rejected", "Completed", "Cancelled", "Withdrawn"] { #expect(!vm.canWithdraw(Sample.carrierOffer(status: status))) }
        #expect(vm.canHide(Sample.carrierOffer(status: "Withdrawn")))
        #expect(!vm.canChat(Sample.carrierOffer(status: "Withdrawn")))
    }

    @Test func withdraw_callsTheServer_thenReloads_andMovesTheOfferToHistory() async {
        let service = FakeOfferService()
        let vm = MyOffersViewModel(service: service)
        service.myOffersResult = .success([Sample.carrierOffer("a", status: "Pending")])
        await vm.load()
        #expect(vm.pendingOffers.map(\.id) == ["a"])

        service.myOffersResult = .success([Sample.carrierOffer("a", status: "Withdrawn")]) // sunucunun yeni cevabı
        await vm.withdraw(Sample.carrierOffer("a", status: "Pending"))

        #expect(service.withdrawnIds == ["a"])
        #expect(vm.pendingOffers.isEmpty)
        #expect(vm.historyOffers.map(\.id) == ["a"])
        #expect(vm.errorMessage == nil)
    }

    @Test func withdraw_failureShowsTheServerMessage_andKeepsTheList() async {
        let service = FakeOfferService()
        let vm = MyOffersViewModel(service: service)
        service.myOffersResult = .success([Sample.carrierOffer("a", status: "Pending")])
        await vm.load()

        service.withdrawResult = .failure(APIError(message: "Yalnız bekleyen teklif geri çekilebilir."))
        await vm.withdraw(Sample.carrierOffer("a", status: "Pending"))

        #expect(vm.errorMessage == "Yalnız bekleyen teklif geri çekilebilir.")
        #expect(vm.pendingOffers.map(\.id) == ["a"]) // liste bozulmadı
    }

    @Test func editAmount_isOnlyForPendingOffers_andStartsWithTheOldAmount() {
        let vm = MyOffersViewModel(service: FakeOfferService())
        #expect(vm.canEditAmount(Sample.carrierOffer(status: "Pending")))
        for status in ["Accepted", "Rejected", "Completed", "Cancelled", "Withdrawn"] { #expect(!vm.canEditAmount(Sample.carrierOffer(status: status))) }

        vm.startEditing(Sample.carrierOffer("a")) // Sample tutarı 1000
        #expect(vm.editingOffer?.id == "a")
        #expect(vm.editAmountText == "1000")
    }

    @Test func saveAmount_resendsTheOfferToTheSameListing_keepsTheNote_andReloads() async {
        let service = FakeOfferService()
        let vm = MyOffersViewModel(service: service)
        vm.editAmountText = " 1500 "

        await vm.saveAmount(Sample.carrierOffer("a", status: "Pending"))

        #expect(service.createCalls.count == 1)
        #expect(service.createCalls.first?.listingId == "l1")
        #expect(service.createCalls.first?.body.amount == 1500) // boşluklar kırpıldı
        #expect(service.createCalls.first?.body.note == "not") // eski not korundu
        #expect(vm.errorMessage == nil)
    }

    @Test func saveAmount_rejectsInvalidAmounts_withoutCallingTheServer() async {
        let service = FakeOfferService()
        let vm = MyOffersViewModel(service: service)
        for text in ["", "abc", "0", "-5", "100000001"] {
            vm.editAmountText = text
            await vm.saveAmount(Sample.carrierOffer())
            #expect(vm.errorMessage != nil)
        }
        #expect(service.createCalls.isEmpty)
    }

    @Test func saveAmount_failureShowsTheServerMessage() async {
        let service = FakeOfferService()
        let vm = MyOffersViewModel(service: service)
        service.createResult = .failure(APIError(message: "Bu ilan artık teklif almıyor."))
        vm.editAmountText = "900"

        await vm.saveAmount(Sample.carrierOffer())

        #expect(vm.errorMessage == "Bu ilan artık teklif almıyor.")
    }

    @Test func stageButton_followsTheJobStage_andOnlyShowsForAcceptedJobs() {
        let vm = MyOffersViewModel(service: FakeOfferService())
        let expected: [(String, String?)] = [("NotStarted", "Yükü aldım"), ("PickedUp", "Yola çıktım"), ("InTransit", "Teslim ettim"), ("Delivered", nil)]
        for (stage, title) in expected {
            let offer = Sample.carrierOffer(status: "Accepted", stage: stage)
            #expect(vm.stage(offer).advanceTitle == title)
            #expect(vm.canAdvance(offer) == (title != nil))
        }
        #expect(!vm.canAdvance(Sample.carrierOffer(status: "Pending"))) // kabul edilmemiş iş ilerletilmez
        #expect(vm.stage(Sample.carrierOffer(stage: "BilinmeyenAsama")).title == "Yük bekleniyor") // bilinmeyen yazı güvenli varsayılana düşer
    }

    @Test func advance_callsTheServer_thenReloads_andShowsTheServerMessageOnFailure() async {
        let service = FakeOfferService()
        let vm = MyOffersViewModel(service: service)
        service.myOffersResult = .success([Sample.carrierOffer("a", status: "Accepted", stage: "NotStarted")])
        await vm.load()

        service.myOffersResult = .success([Sample.carrierOffer("a", status: "Accepted", stage: "PickedUp")])
        await vm.advance(vm.offers[0])
        #expect(service.advancedIds == ["a"])
        #expect(vm.stage(vm.offers[0]) == .pickedUp) // liste yenilendi, yeni aşama görünür
        #expect(vm.errorMessage == nil)

        service.advanceResult = .failure(APIError(message: "Yük zaten teslim edildi."))
        await vm.advance(vm.offers[0])
        #expect(vm.errorMessage == "Yük zaten teslim edildi.")
    }
}
