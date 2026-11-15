//
//  00_Rehber_Models_Security.swift — Models/Security/ — GÜVENLİ SAKLAMA
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: Telefonda güvenle saklanması gereken iki şey: yenileme jetonu ve sabit cihaz kimliği.
//
//  KeychainStore.swift  iOS Keychain sarmalayıcısı: set(_:key:) · get(key:) · remove(key:)
//                       Keychain = şifreli, uygulama silinse bile cihazda kalabilen kasa (UserDefaults DEĞİL: o şifresiz)
//                       Saklanan: "refreshToken" (AuthSession, 30 gün) — "beni hatırla"nın temeli
//  DeviceID.swift       DeviceID.current: bu cihaza ait SABİT kimlik (ilk açılışta üretilir, Keychain'de durur)
//                       → girişte sunucuya gider; yenileme jetonu bu cihaza bağlanır (çalıntı jeton başka cihazda çalışmaz)
//
// KULLANAN: Networking/AuthSession, LoginViewModel, PushManager | arayüz testi: YukumApp "-uiTestReset" refreshToken'ı siler
