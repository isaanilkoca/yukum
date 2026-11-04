//
//  RegisterResponse.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: RegisterResponse (kayıt cevabı) ─────────────────────────────
// │ MODEL     : Kayıt başarılı olunca sunucunun döndüğü kısa özet (id, ad, e-posta, rol)
// │ ÜRETEN    : Sunucu JSON → Core/Networking/APIClient → Features/Auth/AuthService.register / registerCarrier
// │ TÜKETEN   : Features/Auth/RegisterViewModel, CarrierRegisterViewModel (→ Features/Auth/RegisterView, CarrierRegisterView): yalnız "kayıt tamam" sonucunu kullanır, giriş ayrıca yapılır
// └──────────────────────────────────────────────────────────────────────

// API'den dönen başarılı cevap (201). Şifre ve hash asla dönmez.
// Decodable = Swift'in hazır sözü: "gelen JSON'dan bu struct üretilebilir" (JSONDecoder bunu kullanır).
// KULLANAN: AuthService.post, API'nin 201 cevabını bu pakete çevirir ve geri döner (iki kayıt ekranı için de aynı).
// ⮕ KULLANIM [RegisterResponse]: kullanır: AuthService › register(), AuthService › registerCarrier(), AuthServicing › register(), AuthServicing › registerCarrier(), FakeAuthService (test)
struct RegisterResponse : Decodable { // Decodable [SWIFT]: JSON'dan bu türde değer üretilebilir

    // ⮕ KULLANIM [id]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let id : String        // yeni hesabın numarası
    // ⮕ KULLANIM [fullName]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let fullName : String
    // ⮕ KULLANIM [email]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let email : String
    // ⮕ KULLANIM [userType]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let userType : String  // "Shipper" ya da "Carrier"
}
