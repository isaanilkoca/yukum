//
//  CancelRequestTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// Karşılıklı iptal (15 Kasım): düğmenin ne zaman çıktığı + doğru servis çağrısı + başarı/hata. Sunucu gerekmez (FakeOfferService).
@MainActor
struct CancelRequestTests {

    @Test func cancelCanBeRequestedOnlyForAnAcceptedUndeliveredJobWithoutAnOpenRequest() {
        let vm = MyOffersViewModel(service: FakeOfferService())
        var withRequest = Sample.carrierOffer(status: "Accepted")
        withRequest.cancelRequest = CancelRequestInfo(byMe: true, reason: "Araç arızası", note: nil, requestedAt: "2026-11-15T10:00:00Z")
        #expect(vm.canRequestCancel(Sample.carrierOffer(status: "Accepted")))
        #expect(!vm.canRequestCancel(Sample.carrierOffer(status: "Pending")))
        #expect(!vm.canRequestCancel(Sample.carrierOffer(status: "Accepted", stage: "Delivered"))) // teslimden sonra "İşi Bitir"
        #expect(!vm.canRequestCancel(withRequest))                                                // tek açık talep
    }

    @Test func carrierRequestSendsNoListingChoice_andReloads() async {
        let service = FakeOfferService()
        let vm = MyOffersViewModel(service: service)
        let ok = await vm.requestCancel(Sample.carrierOffer("o7", status: "Accepted"), reason: "Araç arızası", note: nil)
        #expect(ok)
        #expect(service.cancelCalls == ["request:o7:Araç arızası:nil"]) // ilanın ne olacağını Taşımacı seçmez
    }

    @Test func shipperApprovalCarriesTheListingChoice() async {
        let service = FakeOfferService()
        let vm = OldOffersViewModel(service: service)
        let ok = await vm.approveCancel(Sample.historyOffer("o9"), reopenListing: false)
        #expect(ok)
        #expect(service.cancelCalls == ["approve:o9:false"])
    }

    @Test func failureShowsTheServerMessage_andReturnsFalse() async {
        let service = FakeOfferService()
        service.cancelResult = .failure(APIError(message: "Bu iş için zaten açık bir iptal talebi var."))
        let vm = MyOffersViewModel(service: service)
        let ok = await vm.rejectCancel(Sample.carrierOffer(status: "Accepted"))
        #expect(!ok)
        #expect(vm.errorMessage == "Bu iş için zaten açık bir iptal talebi var.")
    }
}
