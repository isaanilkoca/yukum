//
//  LoginRequest.swift
//  Yukum
//

import Foundation

// BU DOSYA NE İŞE YARAR?
// Giriş (login) için API ile konuşurken kullanılan paket kalıpları: biri gönderilen, ikisi gelen cevap için.
// [BİZİM] = adı biz koyduk | [SWIFT] = Swift'in hazır kodu
// KURAL: alan adları API'nin JSON alan adlarıyla BİREBİR aynı olmalı (emailOrPhone, accessToken...), yoksa okunamaz.
// API sözleşmesi: docs/api/Auth.md → "POST /api/v1/auth/login"
// MARK: - Giriş (POST /api/v1/auth/login)

// Gönderdiğimiz paket (form kağıdı). Encodable [SWIFT]: "bu struct JSON'a çevrilebilir"
// KULLANAN: Views/LoginView.swift paketi doldurur → AuthService.login gönderir.
struct LoginRequest: Encodable { // LoginRequest [BİZİM]: paketin adı

    let emailOrPhone: String // kullanıcı e-posta ya da telefon yazar; API içinde @ varsa e-posta sayar
    let password: String // şifre; giriş ekranında karmaşıklık denetlenmez, sunucu karar verir
    let deviceId: String // API cihaz kimliği ister (zorunlu) | Security/DeviceID.swift → DeviceID.current: bu cihaza ait SABİT kimlik (Keychain'de) | sunucu yenileme jetonunu bu kimliğe bağlar
}
