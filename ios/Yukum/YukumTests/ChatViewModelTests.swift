//
//  ChatViewModelTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// Sohbet mantığı: gönderme, hata/kilit, temizleme, işi bitirme, otomatik yenileme, ve "kim ne yapabilir" kuralları. Sunucu gerekmez.
@MainActor
struct ChatViewModelTests {

    private func make(canWrite: Bool = true, canComplete: Bool = false, interval: Duration = .seconds(3)) -> (ChatViewModel, FakeChatService) {
        let service = FakeChatService()
        let context = ChatContext(offerId: "o1", title: "Ali", canComplete: canComplete, canWrite: canWrite)
        return (ChatViewModel(context: context, service: service, pollInterval: interval), service)
    }

    @Test func send_trimsTheText_clearsTheDraft_andRefreshesTheMessages() async {
        let (vm, service) = make()
        service.messagesResult = .success([Sample.message(text: "Merhaba")])
        vm.draft = "  Merhaba  "

        await vm.send()

        #expect(service.sent == ["Merhaba"]) // baş/son boşluk temizlendi
        #expect(vm.draft.isEmpty)
        #expect(vm.messages.map(\.text) == ["Merhaba"]) // gönderince liste hemen yenilendi
    }

    @Test func send_ignoresAnEmptyDraft() async {
        let (vm, service) = make()
        vm.draft = "   "
        #expect(vm.canSend == false) // düğme kilitli

        await vm.send()

        #expect(service.sent.isEmpty)
    }

    @Test func failedSend_restoresTheDraft_andShowsTheServerMessage() async {
        let (vm, service) = make()
        service.sendResult = .failure(AuthError(message: "Mesaj boş olamaz."))
        vm.draft = "Merhaba"

        await vm.send()

        #expect(vm.draft == "Merhaba") // yazılan metin kaybolmaz
        #expect(vm.errorMessage == "Mesaj boş olamaz.")
        #expect(vm.canWrite == true) // bu hata sohbeti kilitlemez
    }

    @Test func aClosedChatResponse_locksTheInputImmediately() async {
        let (vm, service) = make(canComplete: true)
        service.sendResult = .failure(AuthError(message: "İş tamamlandı, sohbet kapalı."))
        vm.draft = "Merhaba"

        await vm.send()

        #expect(vm.canWrite == false) // karşı taraf işi bitirmiş: yazma kutusu kapanır
        #expect(vm.canComplete == false) // "İşi bitir" seçeneği de kalkar
    }

    @Test func clear_callsTheServer_andReloadsTheMessages() async {
        let (vm, service) = make()
        await vm.clear()
        #expect(service.clearCalls == 1)
        #expect(service.messageLoads == 1)
    }

    @Test func complete_returnsTrueOnSuccess_andFalseWithTheMessageOnFailure() async {
        let (vm, service) = make(canComplete: true)
        #expect(await vm.complete() == true)

        service.completeResult = .failure(AuthError(message: "Yalnız kabul edilmiş iş tamamlanabilir."))
        #expect(await vm.complete() == false)
        #expect(vm.errorMessage == "Yalnız kabul edilmiş iş tamamlanabilir.")
    }

    @Test func polling_reloadsRepeatedly_andStopsWhenCancelled() async throws {
        let (vm, service) = make(interval: .milliseconds(10))

        let task = Task { await vm.startPolling() }
        try await Task.sleep(for: .milliseconds(120))
        task.cancel() // ekran kapanınca .task iptal edilir
        await task.value
        let loadsAtStop = service.messageLoads

        try await Task.sleep(for: .milliseconds(60))
        #expect(loadsAtStop >= 3) // birkaç kez yeniledi
        #expect(service.messageLoads == loadsAtStop) // iptalden sonra durdu
    }

    // ─── Kim neyi yapabilir? (ChatContext kuralları) ───
    @Test func carrierRules_writeWhenPendingOrAccepted_completeOnlyWhenAccepted() {
        func ctx(_ status: String) -> ChatContext { .forCarrier(Sample.carrierOffer(status: status)) }
        #expect(ctx("Pending").canWrite && !ctx("Pending").canComplete)
        #expect(ctx("Accepted").canWrite && ctx("Accepted").canComplete)
        for closed in ["Rejected", "Completed", "Cancelled"] { #expect(!ctx(closed).canWrite && !ctx(closed).canComplete) }
    }

    @Test func shipperRules_pendingIsWritable_historyOnlyWhenAccepted() {
        #expect(ChatContext.forShipperPending(Sample.listingOffer()).canWrite)
        #expect(!ChatContext.forShipperPending(Sample.listingOffer()).canComplete)
        #expect(ChatContext.forShipperHistory(Sample.historyOffer(status: "Accepted")).canComplete)
        #expect(!ChatContext.forShipperHistory(Sample.historyOffer(status: "Completed")).canWrite)
        #expect(!ChatContext.forShipperHistory(Sample.historyOffer(status: "Rejected")).canWrite)
    }
}
