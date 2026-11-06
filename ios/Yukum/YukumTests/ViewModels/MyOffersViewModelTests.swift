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
        vm.openChat(Sample.carrierOffer("o9", status: "Accepted"))
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
}
