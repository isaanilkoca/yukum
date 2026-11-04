//
//  LoginRequest.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: LoginRequest (giden paket) ──────────────────────────────────
// │ MODEL     : Giriş için sunucuya GİDEN paket: e-posta/telefon + şifre + cihaz kimliği
// │ DOLDURAN  : Features/Auth/LoginViewModel.swift → login() (alanlar: emailOrPhone, password; deviceId: Core/Security/DeviceID.swift)
// │ YOL       : Features/Auth/LoginView (TextField) → LoginViewModel → Features/Auth/AuthService.login(_:) → Core/Networking/APIClient.send(.post) → JSON → POST /api/v1/auth/login
// │ KURAL     : Alan adları API'nin JSON adlarıyla BİREBİR aynı olmalı (Encodable, adlar JSON anahtarı olur)
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA NE İŞE YARAR?
// Giriş (login) için API ile konuşurken kullanılan paket kalıpları: biri gönderilen, ikisi gelen cevap için.
// [BİZİM] = adı biz koyduk | [SWIFT] = Swift'in hazır kodu
// KURAL: alan adları API'nin JSON alan adlarıyla BİREBİR aynı olmalı (emailOrPhone, accessToken...), yoksa okunamaz.
// API sözleşmesi: docs/api/Auth.md → "POST /api/v1/auth/login"
// MARK: - Giriş (POST /api/v1/auth/login)

// Gönderdiğimiz paket (form kağıdı). Encodable [SWIFT]: "bu struct JSON'a çevrilebilir"
// KULLANAN: Features/Auth/LoginView.swift paketi doldurur → AuthService.login gönderir.
// ⮕ KULLANIM [LoginRequest]: kullanır: LoginViewModel › login(), AuthService › login(), AuthServicing › login(), FakeAuthService (test)
struct LoginRequest: Encodable { // LoginRequest [BİZİM]: paketin adı

    // ⮕ KULLANIM [emailOrPhone]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let emailOrPhone: String // kullanıcı e-posta ya da telefon yazar; API içinde @ varsa e-posta sayar
    // ⮕ KULLANIM [password]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let password: String // şifre; giriş ekranında karmaşıklık denetlenmez, sunucu karar verir
    // ⮕ KULLANIM [deviceId]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let deviceId: String // API cihaz kimliği ister (zorunlu) | Core/Security/DeviceID.swift → DeviceID.current: bu cihaza ait SABİT kimlik (Keychain'de) | sunucu yenileme jetonunu bu kimliğe bağlar
}
