
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
    let deviceId: String // API cihaz kimliği ister (zorunlu) | şimdilik her girişte UUID().uuidString [SWIFT: rastgele benzersiz kimlik] ile üreteceğiz
}

// Cevaptaki "user" kutusu: giriş yapan kişinin kısa bilgisi.
// Decodable [SWIFT]: "gelen JSON'dan bu struct üretilebilir"
// KULLANAN: LoginResponse içinde aşağıda | role'e göre anasayfa seçilecek (Yük Veren / Taşımacı).
// BAĞLANTI: View/LoginView.swift'te "loggedInUser" değişkeninin türü bu | View/HomeView.swift'te "user" olarak buraya gelir (ad ve rol oradan okunur).
struct LoginUser: Decodable,Identifiable { // Bu, ekranı "kullanıcı dolunca aç" diye açabilmek için lazım. identifiable

    let id: String // kullanıcı numarası
    let displayName: String // ekranda göstereceğimiz ad ("Hoş geldin Ali")
    let role: String // "Shipper", "Carrier" ya da "Admin" (yazımı API ile aynı)
    // API'nin gönderdiği avatarUrl alanını yazmadık: kullanmayacağımız alanı almayabiliriz, Swift fazlasını yok sayar.
}

// API'den dönen başarılı giriş cevabı (200).
// KULLANAN: AuthService.login bu pakete çevirip geri döner → View/LoginView.swift okur (jeton + kullanıcı).
struct LoginResponse: Decodable {

    let accessToken: String // giriş jetonu (15 dk geçerli); sonraki isteklerde "ben girişliyim" kanıtı → başlıkta "Authorization: Bearer <jeton>"
    let user: LoginUser // cevaptaki "user": { ... } kutusu yukarıdaki LoginUser'a çevrilir
    // accessTokenExpiresAt (bitiş zamanı) alanını şimdilik almıyoruz; yenileme (D4) gelince ekleriz.
}
// Hata cevabı (401 şifre yanlış, 423 kilit...) Yük Veren kaydındaki ile aynı: APIErrorResponse (Network/RegisterRequest.swift), yenisi gerekmez.
