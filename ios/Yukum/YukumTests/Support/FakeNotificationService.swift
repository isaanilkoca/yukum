import Foundation
@testable import Yukum

// Sunucusuz sahte bildirim servisi: sayfaları ve sonuçları test belirler, çağrılar kaydedilir
final class FakeNotificationService: NotificationServicing {
    var pages: [Int: Result<Page<AppNotification>, Error>] = [:]
    var unreadResult: Result<Int, Error> = .success(0)
    var markReadResult: Result<Void, Error> = .success(())
    var markAllResult: Result<Void, Error> = .success(())
    private(set) var listCalls: [Int] = []
    private(set) var markReadCalls: [String] = []
    private(set) var markAllCalls = 0

    func list(page: Int) async throws -> Page<AppNotification> {
        listCalls.append(page)
        return try (pages[page] ?? .success(Page(items: [], page: page, pageSize: 20, totalCount: 0))).get()
    }
    func unreadCount() async throws -> Int { try unreadResult.get() }
    func markRead(id: String) async throws { markReadCalls.append(id); try markReadResult.get() }
    func markAllRead() async throws { markAllCalls += 1; try markAllResult.get() }

    static func item(_ id: String, isRead: Bool = false) -> AppNotification {
        AppNotification(id: id, type: "OfferReceived", title: "Yeni teklif", body: "Metin", listingId: "L1", offerId: "O1", isRead: isRead, createdAt: "2026-11-12T09:00:00Z")
    }
    static func page(_ ids: [String], page: Int = 1, total: Int, read: Bool = false) -> Result<Page<AppNotification>, Error> {
        .success(Page(items: ids.map { item($0, isRead: read) }, page: page, pageSize: 20, totalCount: total))
    }
}
