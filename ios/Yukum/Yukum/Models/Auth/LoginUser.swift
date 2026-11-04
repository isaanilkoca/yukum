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
// ⮕ KULLANIM [LoginUser]: kullanır: HomeViewModel › user, HomeViewModel › init(), LoginViewModel › loggedInUser, AuthSession › restore(), LoginResponse › user, HomeView › init() … +5
nonisolated struct LoginUser: Decodable,Identifiable { // Bu, ekranı "kullanıcı dolunca aç" diye açabilmek için lazım. identifiable | Identifiable [SWIFT]: benzersiz id'si var (List/ForEach'te id: yazmak gerekmez)

    // ⮕ KULLANIM [id]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let id: String // kullanıcı numarası
    // ⮕ KULLANIM [displayName]: okur: HomeView › body, AuthSessionTests (test)
    let displayName: String // ekranda göstereceğimiz ad ("Hoş geldin Ali")
    // ⮕ KULLANIM [role]: okur: HomeViewModel › isShipper, LoginViewModelTests (test)
    let role: String // "Shipper", "Carrier" ya da "Admin" (yazımı API ile aynı)
    // API'nin gönderdiği avatarUrl alanını yazmadık: kullanmayacağımız alanı almayabiliriz, Swift fazlasını yok sayar.
}
