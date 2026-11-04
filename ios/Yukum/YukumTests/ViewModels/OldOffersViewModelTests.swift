//
//  OldOffersViewModelTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// "Eski Teklifler" (Yük Veren) ekranının mantığı: silme kuralı, yükleme. Sunucu gerekmez.
@MainActor
struct OldOffersViewModelTests {

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
}
