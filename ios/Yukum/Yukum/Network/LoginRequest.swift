
//  LoginRequest.swift
//  Yukum
//  Created by İsa Anıl Koca on 29.10.2026.


import Foundation

// BU DOSYA NE İŞE YARAR?
// Giriş (login) için API ile konuşurken kullanılan paket kalıpları: biri gönderilen, ikisi gelen cevap için.
// [BİZİM] = adı biz koyduk | [SWIFT] = Swift'in hazır kodu
// KURAL: alan adları API'nin JSON alan adlarıyla BİREBİR aynı olmalı (emailOrPhone, accessToken...), yoksa okunamaz.
// API sözleşmesi: docs/api/Auth.md → "POST /api/v1/auth/login"

// MARK: - Giriş (POST /api/v1/auth/login)

// Gönderdiğimiz paket (form kağıdı). Encodable [SWIFT]: "bu struct JSON'a çevrilebilir"
// KULLANAN: View/LoginView.swift paketi doldurur → AuthService.login gönderir.
struct LoginRequest: Encodable { // LoginRequest [BİZİM]: paketin adı

    let emailOrPhone: String // kullanıcı e-posta ya da telefon yazar; API içinde @ varsa e-posta sayar
    let password: String // şifre; giriş ekranında karmaşıklık denetlenmez, sunucu karar verir
    let deviceId: String // API cihaz kimliği ister (zorunlu) | Security/DeviceID.swift → DeviceID.current: bu cihaza ait SABİT kimlik (Keychain'de) | sunucu yenileme jetonunu bu kimliğe bağlar
}

// Cevaptaki "user" kutusu: giriş yapan kişinin kısa bilgisi.
// Decodable [SWIFT]: "gelen JSON'dan bu struct üretilebilir"
// KULLANAN: LoginResponse içinde aşağıda | role'e göre anasayfa seçilecek (Yük Veren / Taşımacı).
// BAĞLANTI: View/LoginView.swift'te "loggedInUser" değişkeninin türü bu | View/HomeView.swift'te "user" olarak buraya gelir (ad ve rol oradan okunur).
nonisolated struct LoginUser: Decodable,Identifiable { // Bu, ekranı "kullanıcı dolunca aç" diye açabilmek için lazım. identifiable

    let id: String // kullanıcı numarası
    let displayName: String // ekranda göstereceğimiz ad ("Hoş geldin Ali")
    let role: String // "Shipper", "Carrier" ya da "Admin" (yazımı API ile aynı)
    // API'nin gönderdiği avatarUrl alanını yazmadık: kullanmayacağımız alanı almayabiliriz, Swift fazlasını yok sayar.
}

// API'den dönen başarılı giriş cevabı (200).
// KULLANAN: AuthService.login bu pakete çevirip geri döner → View/LoginView.swift okur (jeton + kullanıcı).
// nonisolated: actor (AuthSession) içinde de çevrilebilsin diye ana iş parçacığı bağından çıkarıldı
nonisolated struct LoginResponse: Decodable {

    let accessToken: String // giriş jetonu (15 dk geçerli); sonraki isteklerde "ben girişliyim" kanıtı → başlıkta "Authorization: Bearer <jeton>" | yalnız BELLEKTE tutulur
    // refreshToken: yenileme jetonu (30 gün) | NE İŞE YARAR: erişim jetonu bitince kullanıcı şifre yazmadan yenisini almak için | NEREDE: AuthSession Keychain'e kaydeder | TEK KULLANIMLIK: her yenilemede yenisi gelir (rotasyon)
    let refreshToken: String
    let user: LoginUser // cevaptaki "user": { ... } kutusu yukarıdaki LoginUser'a çevrilir
    // accessTokenExpiresAt / refreshTokenExpiresAt (bitiş zamanları) alanlarını almıyoruz: jeton süresi dolunca sunucu 401 verir, o zaman yeniliyoruz (reaktif yenileme)
}
// Hata cevabı (401 şifre yanlış, 423 kilit...) Yük Veren kaydındaki ile aynı: APIErrorResponse (Network/RegisterRequest.swift), yenisi gerekmez.
