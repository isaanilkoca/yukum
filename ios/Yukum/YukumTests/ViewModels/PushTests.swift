import Testing
import Foundation
@testable import Yukum

// Push kaydı: adres ve giriş hangi sırayla gelirse gelsin adres sunucuya bir kez ulaşır; çıkışta silinir. Sistem (izin penceresi, Apple) sahte.
@MainActor
struct PushTests {

    private func make() -> (PushManager, FakeNotificationService) {
        let service = FakeNotificationService()
        return (PushManager(service: service, requestSystem: {}, applyBadge: { _ in }), service)
    }

    private let rawToken = Data([0x0a, 0xff, 0x01, 0x10])

    // Soğuk açılış: dokunuş, ana ekran kurulmadan önce gelir; not saklanmalı ve yalnız BİR kez okunmalı
    @Test func tapWhileTheHomeScreenIsNotReadyIsKeptAndReadOnlyOnce() {
        let manager = PushManager(service: FakeNotificationService(), requestSystem: {}, applyBadge: { _ in })
        #expect(!manager.takePendingTap()) // dokunuş yokken liste açılmaz

        manager.noteTap()

        #expect(manager.takePendingTap()) // ana ekran açılınca okur
        #expect(!manager.takePendingTap()) // ikinci okuyuşta yok: liste iki kez açılmaz
    }

    @Test func tokenBytesBecomeLowercaseHexWithLeadingZeros() {
        #expect(PushManager.hex(rawToken) == "0aff0110")
    }

    @Test func tokenThatArrivesAfterLoginIsSentToTheServer() async {
        let (push, service) = make()

        await push.enable()                       // giriş yapıldı, adres henüz yok
        #expect(service.registerCalls.isEmpty)
        await push.didReceive(deviceToken: rawToken)

        #expect(service.registerCalls.map(\.token) == ["0aff0110"])
        #expect(service.registerCalls.first?.deviceId == DeviceID.current)
        #expect(service.registerCalls.first?.sandbox == true) // testler Debug derlenir
    }

    @Test func tokenThatArrivesBeforeLoginWaitsUntilLogin() async {
        let (push, service) = make()

        await push.didReceive(deviceToken: rawToken) // uygulama açıldı, kullanıcı henüz giriş yapmadı
        #expect(service.registerCalls.isEmpty)
        await push.enable()

        #expect(service.registerCalls.map(\.token) == ["0aff0110"])
    }

    @Test func logoutRemovesTheDeviceAndStopsSendingTokens() async {
        let (push, service) = make()
        await push.enable()
        await push.didReceive(deviceToken: rawToken)

        await push.unregister()
        await push.unregister()                       // ikinci kez: istek atılmaz
        await push.didReceive(deviceToken: rawToken)  // çıkıştan sonra gelen adres gönderilmez

        #expect(service.removeCalls == [DeviceID.current])
        #expect(service.registerCalls.count == 1)
    }

    @Test func serverFailureDoesNotCrashOrBlock() async {
        let (push, service) = make()
        service.deviceResult = .failure(APIError(message: "Sunucuya ulaşılamadı."))

        await push.enable()
        await push.didReceive(deviceToken: rawToken)
        await push.unregister()

        #expect(service.registerCalls.count == 1) // denendi, hata yutuldu (uygulama içi bildirimler etkilenmez)
        #expect(!push.isActive)
    }

    // ---- HomeViewModel bağlantıları ----

    private func home(_ notifications: FakeNotificationService, _ push: FakePush, _ session: FakeSession = FakeSession()) -> HomeViewModel {
        HomeViewModel(user: Sample.carrier, listingService: FakeListingService(), offerService: FakeOfferService(), notificationService: notifications,
                      push: push, cityService: FakeCityService(), session: session, location: FakeLocation())
    }

    @Test func unreadCountFillsTheBellAndTheAppIconBadge() async {
        let notifications = FakeNotificationService(), push = FakePush()
        notifications.unreadResult = .success(3)
        let viewModel = home(notifications, push)

        await viewModel.loadUnread()

        #expect(viewModel.unreadNotifications == 3)
        #expect(push.badge == 3)
    }

    @Test func unreadCountKeepsTheOldValueWhenTheServerFails() async {
        let notifications = FakeNotificationService(), push = FakePush()
        notifications.unreadResult = .success(2)
        let viewModel = home(notifications, push)
        await viewModel.loadUnread()

        notifications.unreadResult = .failure(APIError(message: "x"))
        await viewModel.loadUnread()

        #expect(viewModel.unreadNotifications == 2) // rozet için hata gösterilmez, eski sayı kalır
    }

    @Test func signOutRemovesThePushAddressBeforeClosingTheSession() async {
        let push = FakePush(), session = FakeSession()
        let viewModel = home(FakeNotificationService(), push, session)

        await viewModel.enablePush()
        await viewModel.signOut()

        #expect(push.events == ["enable", "unregister"])
        #expect(session.signOutCalls == 1)
    }
}
