//
//  DeviceID.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: DeviceID (cihaz kimliği) ────────────────────────────────────
// │ KULLANAN  : ViewModels/LoginViewModel (deviceId: { DeviceID.current } → LoginRequest.deviceId) | Models/Networking/AuthSession.performRefresh (yenilemede aynı kimlik)
// │ NEDEN SABİT: Sunucu yenileme jetonunu cihaza bağlar; her seferinde yeni kimlik olsaydı yenileme reddedilirdi
// │ SAKLAR    : Models/Security/KeychainStore (uygulama silinip kurulsa bile aynı kalır)
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA: bu cihaza ait SABİT bir kimlik üretir ve Keychain'de saklar.
// NEDEN GEREKLİ: sunucu yenileme jetonunu cihaza BAĞLAR (başka cihazdan yenilenemez) ve cihaz başına tek oturum tutar.
// Daha önce her girişte yeni UUID üretiyorduk; bu, "cihaz" kavramını anlamsız yapar (her giriş yeni cihaz sayılırdı).
// NEDEN Keychain: uygulama silinip yeniden kurulsa bile aynı kimlik korunur (UserDefaults silinirdi) → kullanıcının eski oturumu sunucuda "aynı cihaz" olarak düşer.
// BAĞLANTI: Views/LoginView.swift girişte gönderir | Models/Networking/AuthSession.swift yenilemede gönderir
// ⮕ KULLANIM [DeviceID]: kullanır: LoginViewModel › init(), AuthSession › performRefresh()
nonisolated enum DeviceID { // enum [SWIFT]: sabit seçenek listesi

    // ⮕ KULLANIM [key]: okur: DeviceID › current
    private static let key = "deviceId" // Keychain'deki kaydın adı | static [SWIFT]: türün kendisine ait (örnek üretmeden erişilir)

    // current: bu cihazın kimliği | ilk çağrıda üretilip kaydedilir, sonra hep aynısı döner
    // ⮕ KULLANIM [current]: okur: AuthSession › performRefresh(), CreateListingViewModelTests (test)
    static var current: String {
        if let saved = KeychainStore.get(key: key) { return saved } // daha önce üretildiyse onu kullan
        let new = UUID().uuidString // UUID [SWIFT]: rastgele, benzersiz kimlik
        KeychainStore.set(new, key: key)
        return new
    }
}
