//
//  RegisterResponse.swift
//  Yukum
//

import Foundation

// API'den dönen başarılı cevap (201). Şifre ve hash asla dönmez.
// Decodable = Swift'in hazır sözü: "gelen JSON'dan bu struct üretilebilir" (JSONDecoder bunu kullanır).
// KULLANAN: AuthService.post, API'nin 201 cevabını bu pakete çevirir ve geri döner (iki kayıt ekranı için de aynı).
struct RegisterResponse : Decodable {

    let id : String        // yeni hesabın numarası
    let fullName : String
    let email : String
    let userType : String  // "Shipper" ya da "Carrier"
}
