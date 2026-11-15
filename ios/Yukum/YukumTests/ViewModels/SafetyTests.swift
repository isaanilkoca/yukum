//
//  SafetyTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// Engelle + Şikâyet et (15 Kasım): SafetyViewModel, BlockedUsersViewModel, sohbetin karşı taraf numarası. Sunucu yok, sahte servis.
@MainActor
struct SafetyTests {

    @Test func load_marksTheTargetAsBlocked_onlyIfItIsInMyBlockList() async {
        let service = FakeSafetyService()
        service.blockedList = [BlockedUser(userId: "u2", fullName: "Ali", blockedAt: "2026-11-15T10:00:00Z")]
        let blocked = SafetyViewModel(target: SafetyTarget(userId: "u2", name: "Ali"), service: service)
        let other = SafetyViewModel(target: SafetyTarget(userId: "u3", name: "Veli"), service: service)

        await blocked.load(); await other.load()

        #expect(blocked.isBlocked)
        #expect(!other.isBlocked)
    }

    @Test func setBlocked_callsTheRightEndpoint_andFlipsTheMenuState() async {
        let service = FakeSafetyService()
        let vm = SafetyViewModel(target: SafetyTarget(userId: "u2", name: "Ali"), service: service)

        #expect(await vm.setBlocked(true))
        #expect(vm.isBlocked && service.blockCalls == ["u2"])
        #expect(await vm.setBlocked(false))
        #expect(!vm.isBlocked && service.unblockCalls == ["u2"])
    }

    @Test func setBlocked_onError_keepsTheOldState_andShowsAMessage() async {
        let service = FakeSafetyService(); service.failNext = true
        let vm = SafetyViewModel(target: SafetyTarget(userId: "u2", name: "Ali"), service: service)

        #expect(await vm.setBlocked(true) == false)
        #expect(!vm.isBlocked)
        #expect(vm.errorMessage != nil)
    }

    @Test func report_sendsTheServerReasonName_trimmedNote_andTheContext() async {
        let service = FakeSafetyService()
        let vm = SafetyViewModel(target: SafetyTarget(userId: "u2", name: "Ali", listingId: "l1", offerId: nil), service: service)

        let error = await vm.report(reasonTitle: ReportReason.fakeListing.title, note: "  sahte ilan  ")

        #expect(error == nil)
        #expect(service.reportCalls.count == 1)
        let body = service.reportCalls[0].body
        #expect(service.reportCalls[0].userId == "u2")
        #expect(body.reason == "FakeListing" && body.note == "sahte ilan" && body.listingId == "l1" && body.offerId == nil)
    }

    @Test func report_rejectsAnEmptyReason_andATooLongNote_withoutCallingTheServer() async {
        let service = FakeSafetyService()
        let vm = SafetyViewModel(target: SafetyTarget(userId: "u2", name: "Ali"), service: service)

        #expect(await vm.report(reasonTitle: "", note: "") != nil)
        #expect(await vm.report(reasonTitle: ReportReason.spam.title, note: String(repeating: "a", count: 501)) != nil)
        #expect(service.reportCalls.isEmpty)
        #expect(await vm.report(reasonTitle: ReportReason.other.title, note: "   ") == nil) // boş not gönderilmez ama şikâyet gider
        #expect(service.reportCalls.first?.body.note == nil)
    }

    @Test func blockedUsers_loadsAndUnblockRemovesTheRowImmediately() async {
        let service = FakeSafetyService()
        service.blockedList = [BlockedUser(userId: "u2", fullName: "Ali", blockedAt: "x"), BlockedUser(userId: "u3", fullName: "Veli", blockedAt: "y")]
        let vm = BlockedUsersViewModel(service: service)

        await vm.load()
        #expect(vm.users.count == 2)
        #expect(await vm.unblock(vm.users[0]))
        #expect(vm.users.map(\.userId) == ["u3"])
        #expect(service.unblockCalls == ["u2"])
    }

    @Test func carrierOffer_decodesTheShipperId_andChatKnowsTheOtherSide() throws {
        let json = #"{"id":"o1","listingId":"l1","listingTitle":"İlan","fromCityName":"Mersin","fromDistrictName":"Merkez","toCityName":"İstanbul","toDistrictName":"Kadıköy","shipperName":"Ayşe","shipperId":"s9","weightKg":1000,"pickupDate":"2026-11-20","amount":1000,"status":"Pending","isNew":false,"stage":"NotStarted"}"#
        let offer = try JSONDecoder().decode(CarrierOffer.self, from: Data(json.utf8))

        #expect(offer.shipperId == "s9")
        #expect(ChatContext.forCarrier(offer).otherUserId == "s9")
        #expect(ReportReason.from(title: "Dolandırıcılık") == .fraud)
    }
}
