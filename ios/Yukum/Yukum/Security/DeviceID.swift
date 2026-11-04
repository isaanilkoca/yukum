//
//  DeviceID.swift
//  Yukum
//

import Foundation

// BU DOSYA: bu cihaza ait SABİT bir kimlik üretir ve Keychain'de saklar.
// NEDEN GEREKLİ: sunucu yenileme jetonunu cihaza BAĞLAR (başka cihazdan yenilenemez) ve cihaz başına tek oturum tutar.
// Daha önce her girişte yeni UUID üretiyorduk; bu, "cihaz" kavramını anlamsız yapar (her giriş yeni cihaz sayılırdı).
// NEDEN Keychain: uygulama silinip yeniden kurulsa bile aynı kimlik korunur (UserDefaults silinirdi) → kullanıcının eski oturumu sunucuda "aynı cihaz" olarak düşer.
// BAĞLANTI: Views/LoginView.swift girişte gönderir | Networking/AuthSession.swift yenilemede gönderir
nonisolated enum DeviceID {

    private static let key = "deviceId" // Keychain'deki kaydın adı

    // current: bu cihazın kimliği | ilk çağrıda üretilip kaydedilir, sonra hep aynısı döner
    static var current: String {
        if let saved = KeychainStore.get(key: key) { return saved } // daha önce üretildiyse onu kullan
        let new = UUID().uuidString // UUID [SWIFT]: rastgele, benzersiz kimlik
        KeychainStore.set(new, key: key)
        return new
    }
}
