//
//  RegisterResponse.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: RegisterResponse (kayıt cevabı) ─────────────────────────────
// │ MODEL     : Kayıt başarılı olunca sunucunun döndüğü kısa özet (id, ad, e-posta, rol)
// │ ÜRETEN    : Sunucu JSON → Networking/APIClient → Services/AuthService.register / registerCarrier
// │ TÜKETEN   : ViewModels/RegisterViewModel, CarrierRegisterViewModel (→ Views/RegisterView, CarrierRegisterView): yalnız "kayıt tamam" sonucunu kullanır, giriş ayrıca yapılır
// └──────────────────────────────────────────────────────────────────────

// API'den dönen başarılı cevap (201). Şifre ve hash asla dönmez.
// Decodable = Swift'in hazır sözü: "gelen JSON'dan bu struct üretilebilir" (JSONDecoder bunu kullanır).
// KULLANAN: AuthService.post, API'nin 201 cevabını bu pakete çevirir ve geri döner (iki kayıt ekranı için de aynı).
struct RegisterResponse : Decodable { // Decodable [SWIFT]: JSON'dan bu türde değer üretilebilir

    let id : String        // yeni hesabın numarası
    let fullName : String
    let email : String
    let userType : String  // "Shipper" ya da "Carrier"
}
