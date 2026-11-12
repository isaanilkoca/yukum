import Foundation
@testable import Yukum

// Sahte push kaydı: izin penceresi açmaz, yalnız hangi sırayla ne çağrıldığını kaydeder
final class FakePush: PushRegistering {
    private(set) var events: [String] = []
    private(set) var badge: Int?
    func enable() async { events.append("enable") }
    func unregister() async { events.append("unregister") }
    func setBadge(_ count: Int) { badge = count }
}
