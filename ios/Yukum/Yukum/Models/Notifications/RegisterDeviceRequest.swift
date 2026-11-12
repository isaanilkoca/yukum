import Foundation

// Giden paket: telefonun push adresini sunucuya bildirir | API: PUT /api/v1/notifications/device-token
// BAĞLANTI: PushManager.sendIfReady() hazırlar → NotificationService.registerDevice gönderir → backend DeviceTokens tablosu
struct RegisterDeviceRequest: Encodable { // Encodable [SWIFT]: bu struct JSON'a çevrilebilir
    let token: String // APNs cihaz jetonu (onaltılık yazı): "bu telefondaki bu uygulamanın" adresi
    let deviceId: String // uygulamanın kendi cihaz kimliği (Models/Security/DeviceID) | çıkışta bu kimlikle silinir
    let sandbox: Bool // true: Xcode'dan kurulan geliştirme sürümü (Apple'ın test sunucusu) | false: TestFlight / App Store
}
