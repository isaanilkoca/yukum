//
//  LoginUser.swift
//  Yukum
//

import Foundation

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
