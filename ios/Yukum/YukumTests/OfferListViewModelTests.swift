//
//  OfferListViewModelTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// Teklif listesi ekranlarının mantığı: bölümler, silme kuralları, karar, ilanı kaldırma, hata/yenileme. Sunucu gerekmez.
@MainActor
struct OfferListViewModelTests {

    // ─── Tekliflerim (Taşımacı) ───
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

        service.hideResult = .failure(AuthError(message: "Kabul edilmiş teklif aktif iştir."))
        await vm.hide(Sample.carrierOffer("y", status: "Accepted"))
        #expect(vm.errorMessage == "Kabul edilmiş teklif aktif iştir.")
    }

    @Test func myOffers_openChatBuildsTheCarrierContext() {
        let vm = MyOffersViewModel(service: FakeOfferService())
        vm.openChat(Sample.carrierOffer("o9", status: "Accepted"))
        #expect(vm.chat?.offerId == "o9")
        #expect(vm.chat?.canComplete == true)
    }

    // ─── Gelen Teklifler (Yük Veren) ───
    @Test func incomingOffers_decideCallsTheServerAndReloads() async {
        let service = FakeOfferService()
        service.listingOffersResult = .success([Sample.listingOffer("o1")])
        let vm = ListingOffersViewModel(listing: Sample.listing(), offerService: service, listingService: FakeListingService())

        await vm.decide(Sample.listingOffer("o1"), accept: true)

        #expect(service.decisions.count == 1)
        #expect(service.decisions[0].id == "o1" && service.decisions[0].accept == true)
        #expect(vm.offers.map(\.id) == ["o1"]) // karardan sonra liste yenilendi
    }

    @Test func incomingOffers_aFailedDecisionShowsTheServerMessage() async {
        let service = FakeOfferService()
        service.decideResult = .failure(AuthError(message: "Bu teklif için karar zaten verilmiş."))
        let vm = ListingOffersViewModel(listing: Sample.listing(), offerService: service, listingService: FakeListingService())

        await vm.decide(Sample.listingOffer(), accept: false)

        #expect(vm.errorMessage == "Bu teklif için karar zaten verilmiş.")
    }

    @Test func cancelListing_returnsTrueOnSuccess_andFalseWithAMessageOnFailure() async {
        let listings = FakeListingService()
        let vm = ListingOffersViewModel(listing: Sample.listing("L1"), offerService: FakeOfferService(), listingService: listings)

        #expect(await vm.cancelListing() == true)
        #expect(listings.cancelledIds == ["L1"])

        listings.cancelResult = .failure(AuthError(message: "Bu ilan zaten tamamlanmış ya da kaldırılmış."))
        #expect(await vm.cancelListing() == false)
        #expect(vm.errorMessage == "Bu ilan zaten tamamlanmış ya da kaldırılmış.")
    }

    // ─── Eski Teklifler (Yük Veren) ───
    @Test func oldOffers_onlyRejectedOrCompletedCanBeHidden() {
        let vm = OldOffersViewModel(service: FakeOfferService())
        #expect(vm.canHide(Sample.historyOffer(status: "Rejected")))
        #expect(vm.canHide(Sample.historyOffer(status: "Completed")))
        #expect(!vm.canHide(Sample.historyOffer(status: "Accepted"))) // aktif iş silinmez
    }

    @Test func oldOffers_loadAndHide() async {
        let service = FakeOfferService()
        service.historyResult = .success([Sample.historyOffer("h1", status: "Rejected")])
        let vm = OldOffersViewModel(service: service)

        await vm.load()
        await vm.hide(vm.offers[0])

        #expect(vm.offers.count == 1) // fake aynı listeyi döner; önemli olan çağrıların yapılması
        #expect(service.hiddenIds == ["h1"])
    }

    @Test func aCancelledRequest_isNotShownAsAnError() async {
        let service = FakeOfferService()
        service.myOffersResult = .failure(URLError(.cancelled))
        let vm = MyOffersViewModel(service: service)

        await vm.load()

        #expect(vm.errorMessage == nil) // iptal hata değildir
    }
}
