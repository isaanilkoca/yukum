import Testing
@testable import Yukum

@MainActor
struct NotificationsViewModelTests {

    @Test func loadFillsTheListAndKnowsThereIsMore() async {
        let service = FakeNotificationService()
        service.pages[1] = FakeNotificationService.page(["a", "b"], total: 3)
        let viewModel = NotificationsViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.items.map(\.id) == ["a", "b"])
        #expect(viewModel.hasMore)
        #expect(viewModel.hasUnread)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func loadMoreAppendsTheNextPageWithoutRepeats() async {
        let service = FakeNotificationService()
        service.pages[1] = FakeNotificationService.page(["a", "b"], total: 3)
        service.pages[2] = FakeNotificationService.page(["b", "c"], page: 2, total: 3) // "b" tekrar geldi (araya yeni bildirim girmiş)
        let viewModel = NotificationsViewModel(service: service)
        await viewModel.load()

        await viewModel.loadMore()
        await viewModel.loadMore() // hepsi yüklendi: yeni istek atılmaz

        #expect(viewModel.items.map(\.id) == ["a", "b", "c"])
        #expect(!viewModel.hasMore)
        #expect(service.listCalls == [1, 2])
    }

    @Test func loadFailureShowsTheServerMessage() async {
        let service = FakeNotificationService()
        service.pages[1] = .failure(APIError(message: "Bildirimler yüklenemedi."))
        let viewModel = NotificationsViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.items.isEmpty)
        #expect(viewModel.errorMessage == "Bildirimler yüklenemedi.")
    }

    @Test func markReadUpdatesTheRowAndCallsTheServerOnce() async {
        let service = FakeNotificationService()
        service.pages[1] = FakeNotificationService.page(["a", "b"], total: 2)
        let viewModel = NotificationsViewModel(service: service)
        await viewModel.load()

        await viewModel.markRead(viewModel.items[0])
        await viewModel.markRead(viewModel.items[0]) // zaten okundu: istek atılmaz

        #expect(viewModel.items[0].isRead)
        #expect(!viewModel.items[1].isRead)
        #expect(service.markReadCalls == ["a"])
    }

    @Test func markReadIsUndoneWhenTheServerRefuses() async {
        let service = FakeNotificationService()
        service.pages[1] = FakeNotificationService.page(["a"], total: 1)
        service.markReadResult = .failure(APIError(message: "Bildirim güncellenemedi."))
        let viewModel = NotificationsViewModel(service: service)
        await viewModel.load()

        await viewModel.markRead(viewModel.items[0])

        #expect(!viewModel.items[0].isRead) // iyimser güncelleme geri alındı
        #expect(viewModel.errorMessage == "Bildirim güncellenemedi.")
    }

    @Test func markAllReadClearsEveryRowAndIsUndoneOnFailure() async {
        let service = FakeNotificationService()
        service.pages[1] = FakeNotificationService.page(["a", "b"], total: 2)
        let viewModel = NotificationsViewModel(service: service)
        await viewModel.load()

        await viewModel.markAllRead()
        #expect(!viewModel.hasUnread)
        await viewModel.markAllRead() // okunmamış yok: istek atılmaz
        #expect(service.markAllCalls == 1)

        service.markAllResult = .failure(APIError(message: "Bildirimler güncellenemedi."))
        await viewModel.load() // sunucudan yeniden okunmamış geldi
        await viewModel.markAllRead()
        #expect(viewModel.hasUnread) // geri alındı
        #expect(viewModel.errorMessage == "Bildirimler güncellenemedi.")
    }

    @Test func deleteRemovesTheRowAndKeepsHasMoreCorrect() async {
        let service = FakeNotificationService()
        service.pages[1] = FakeNotificationService.page(["a", "b", "c"], total: 3)
        let viewModel = NotificationsViewModel(service: service)
        await viewModel.load()
        let removed = viewModel.items[1]

        await viewModel.delete(removed)
        await viewModel.delete(removed) // listede yok: istek atılmaz

        #expect(viewModel.items.map(\.id) == ["a", "c"])
        #expect(viewModel.totalCount == 2)
        #expect(!viewModel.hasMore) // toplam da azaldı: gereksiz sayfa isteği olmaz
        #expect(service.deleteCalls == ["b"])
    }

    @Test func deleteIsUndoneInPlaceWhenTheServerRefuses() async {
        let service = FakeNotificationService()
        service.pages[1] = FakeNotificationService.page(["a", "b", "c"], total: 3)
        service.deleteResult = .failure(APIError(message: "Bildirim silinemedi."))
        let viewModel = NotificationsViewModel(service: service)
        await viewModel.load()

        await viewModel.delete(viewModel.items[1])

        #expect(viewModel.items.map(\.id) == ["a", "b", "c"]) // sona değil, eski yerine döndü
        #expect(viewModel.totalCount == 3)
        #expect(viewModel.errorMessage == "Bildirim silinemedi.")
    }
}
