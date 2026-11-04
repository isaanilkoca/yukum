//
//  KeychainStore.swift
//  Yukum
//

import Foundation
import Security // [SWIFT] Apple'ın güvenlik çerçevesi: Keychain (anahtar zinciri) buradan gelir

// BU DOSYA: Keychain'e küçük bir metin (jeton gibi) kaydetme/okuma/silme.
// KEYCHAIN NEDİR: iOS'un şifreli, uygulamaya özel güvenli deposu. Uygulama kapansa, telefon yeniden başlasa bile veri durur.
// NEDEN UserDefaults DEĞİL: UserDefaults şifresiz düz dosyadır, yedekten okunabilir; jeton gibi sırlar orada SAKLANMAZ.
// NE SAKLANIR: yenileme jetonu (refresh token) ve cihaz kimliği | erişim jetonu (15 dk) yalnız bellekte durur, diske yazılmaz
// BAĞLANTI: Networking/AuthSession.swift (yenileme jetonu) ve Security/DeviceID.swift (cihaz kimliği) kullanır
// nonisolated [SWIFT]: projede her şey varsayılan olarak ana iş parçacığına bağlı; bu araç her yerden (actor içinden de) çağrılabilsin diye bağsız işaretlendi
nonisolated enum KeychainStore { // enum: örnek üretilmeyen, sadece ortak fonksiyon taşıyan kutu | adı [BİZİM]

    // service: bu uygulamanın kutusu | aynı key farklı uygulamalarda karışmasın diye uygulama kimliği (bundle id) kullanılır
    static let defaultService = Bundle.main.bundleIdentifier ?? "com.isaanilkoca.Yukum"

    // Her Keychain kaydı "sınıf + servis + hesap(anahtar)" üçlüsüyle bulunur. Bu üçlü sorgunun ortak kısmıdır.
    // kSecClassGenericPassword [SWIFT]: "genel amaçlı parola/metin kaydı" türü | kSecAttrService: kutu adı | kSecAttrAccount: kaydın adı (bizim "key")
    private static func query(key: String, service: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    // set: kaydet (varsa üzerine yaz) | -> Bool: başarılı mı | @discardableResult: sonucu kullanmasan da uyarı verme
    @discardableResult
    static func set(_ value: String, key: String, service: String = defaultService) -> Bool {
        let data = Data(value.utf8) // metni bayt dizisine çevir (Keychain bayt saklar)
        // kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly: telefon açılıp bir kez kilit açıldıktan sonra erişilir (uygulama arka planda jeton yenileyebilir) + yalnız BU cihazda kalır (yedekle/başka cihaza taşınmaz)
        let attributes: [String: Any] = [kSecValueData as String: data,
                                         kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        // Önce güncellemeyi dene: kayıt zaten varsa değeri değiştirir
        let status = SecItemUpdate(query(key: key, service: service) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound { // yoksa yeni kayıt ekle
            let item = query(key: key, service: service).merging(attributes) { _, new in new } // iki sözlüğü birleştir
            return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    // get: oku | -> String?: kayıt yoksa nil
    static func get(key: String, service: String = defaultService) -> String? {
        var request = query(key: key, service: service)
        request[kSecReturnData as String] = true // veriyi geri ver
        request[kSecMatchLimit as String] = kSecMatchLimitOne // tek kayıt
        var result: AnyObject? // sonuç buraya dolar
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess, // & = sonucun yazılacağı yer
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8) // bayt dizisini metne çevir
    }

    // remove: sil (kayıt yoksa sessizce geç)
    static func remove(key: String, service: String = defaultService) {
        SecItemDelete(query(key: key, service: service) as CFDictionary)
    }
}
