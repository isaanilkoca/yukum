//
//  LoginUser.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: LoginUser (giriş yapan kişi) ────────────────────────────────
// │ MODEL     : Giriş yapan kişinin kısa bilgisi: id, görünen ad, rol ("Shipper" / "Carrier")
// │ ÜRETEN    : LoginResponse.user (sunucu JSON) | AuthSession.restore() (otomatik giriş)
// │ SAKLAYAN  : LoginViewModel.loggedInUser → Views/LoginView.fullScreenCover → Views/HomeView(user:) → HomeViewModel.user
// │ KULLANIM  : HomeViewModel.isShipper rolü okur: Yük Veren mi Taşımacı mı ekranı bu karar belirler (Views/HomeView if/else)
// └──────────────────────────────────────────────────────────────────────

// Cevaptaki "user" kutusu: giriş yapan kişinin kısa bilgisi.
// Decodable [SWIFT]: "gelen JSON'dan bu struct üretilebilir"
// KULLANAN: LoginResponse içinde aşağıda | role'e göre anasayfa seçilecek (Yük Veren / Taşımacı).
// BAĞLANTI: Views/LoginView.swift'te "loggedInUser" değişkeninin türü bu | Views/HomeView.swift'te "user" olarak buraya gelir (ad ve rol oradan okunur).
nonisolated struct LoginUser: Decodable,Identifiable { // Bu, ekranı "kullanıcı dolunca aç" diye açabilmek için lazım. identifiable

    let id: String // kullanıcı numarası
    let displayName: String // ekranda göstereceğimiz ad ("Hoş geldin Ali")
    let role: String // "Shipper", "Carrier" ya da "Admin" (yazımı API ile aynı)
    // API'nin gönderdiği avatarUrl alanını yazmadık: kullanmayacağımız alanı almayabiliriz, Swift fazlasını yok sayar.
}
