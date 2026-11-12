import UIKit // UIApplication (Apple'a push kaydı) bu kütüphanede
import UserNotifications // [SWIFT] bildirim izni ve simge sayısı

// ┌─ BAĞLANTI HARİTASI: PushManager (telefon bildirimi kaydı) ────────────────────────
// │ 1) HomeView .task → HomeViewModel.enablePush() → enable(): izin penceresi → UIApplication.registerForRemoteNotifications()
// │ 2) Apple adresi verir → App/AppDelegate didRegisterForRemoteNotifications… → didReceive(deviceToken:)
// │ 3) sendIfReady() → NotificationService.registerDevice → PUT /api/v1/notifications/device-token → backend DeviceTokens
// │ 4) Çıkış: HomeViewModel.signOut() → unregister() → DELETE /api/v1/notifications/device-token
// │ SUNUCU: bildirim satırı yazılır → PushWorker → Apple (APNs) → telefon | bkz. docs/api/Notifications.md
// └──────────────────────────────────────────────────────────────────────

// Adres (2) ile giriş (1) hangi sırayla gelirse gelsin çalışır: adres ancak İKİSİ de hazırsa gönderilir (isActive + token)
final class PushManager: PushRegistering {
    static let shared = PushManager() // static let [SWIFT]: tek ortak örnek | AppDelegate ve HomeViewModel AYNI nesneyle konuşur

    private let service: NotificationServicing
    private let requestSystem: () async -> Void // closure [SWIFT]: sistem işi dışarıdan verilir → testte izin penceresi açılmaz
    private let applyBadge: (Int) -> Void

    private(set) var token: String? // Apple'ın verdiği adres | nil: henüz gelmedi (ya da izin verilmedi)
    private(set) var isActive = false // true: giriş yapılmış, adres sunucuya gönderilebilir

    // @escaping [SWIFT]: closure saklanıp SONRA çağrılacaksa yazılır
    init(service: NotificationServicing = NotificationService(),
         requestSystem: @escaping () async -> Void = PushManager.askPermissionAndRegister,
         applyBadge: @escaping (Int) -> Void = { count in Task { try? await UNUserNotificationCenter.current().setBadgeCount(count) } }) {
        self.service = service
        self.requestSystem = requestSystem
        self.applyBadge = applyBadge
    }

    // enable: giriş yapılmış ekran açılınca | izin daha önce verildiyse pencere çıkmaz, yalnız kayıt yenilenir
    func enable() async {
        isActive = true
        await requestSystem()
        await sendIfReady() // adres önceden geldiyse şimdi gönder
    }

    // didReceive: Apple adresi verdi | Data [SWIFT]: ham baytlar → sunucunun beklediği onaltılık yazıya çevrilir
    func didReceive(deviceToken: Data) async {
        token = Self.hex(deviceToken)
        await sendIfReady() // giriş yapılmışsa şimdi gönder
    }

    // unregister: çıkıştan ÖNCE çağrılır (silme isteği jeton ister) | try? [SWIFT]: hata olsa da çıkış engellenmez
    func unregister() async {
        guard isActive else { return }
        isActive = false
        try? await service.removeDevice(deviceId: DeviceID.current)
    }

    func setBadge(_ count: Int) { applyBadge(count) }

    private func sendIfReady() async {
        guard isActive, let token else { return } // ikisi de hazır değilse bekle
        try? await service.registerDevice(RegisterDeviceRequest(token: token, deviceId: DeviceID.current, sandbox: Self.isSandbox))
    }

    // hex: baytları iki haneli onaltılık yazıya çevirip birleştirir | %02x: 2 hane, küçük harf, başı sıfır dolgulu (10 → "0a")
    static func hex(_ data: Data) -> String { data.map { String(format: "%02x", $0) }.joined() }

    // #if DEBUG [SWIFT]: derleme anında seçilir | Xcode'dan çalıştırma = Debug = Apple'ın "sandbox" sunucusu
    static var isSandbox: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    // İzin penceresi (yalnız ilk kez çıkar) + Apple'a kayıt | sonuç AppDelegate'e gelir (adres ya da hata)
    static func askPermissionAndRegister() async {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        if granted { UIApplication.shared.registerForRemoteNotifications() }
    }
}

// Uygulama içi anonslar (NotificationCenter): AppDelegate yayınlar, HomeView dinler
extension Notification.Name {
    static let pushTapped = Notification.Name("yukum.pushTapped") // kullanıcı bildirime dokundu → bildirim listesi açılır
    static let pushReceived = Notification.Name("yukum.pushReceived") // uygulama açıkken bildirim geldi → zil sayısı tazelenir
}
