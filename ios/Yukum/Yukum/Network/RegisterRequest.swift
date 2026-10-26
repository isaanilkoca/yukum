//
//  RegisterRequest.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import Foundation

// Bunlar API ile konuşurken kullanılan "paketler".

struct RegisterRequest: Encodable { // Encodable: struct'ı JSON'a çevirir
    
    let fullName : String // adlar API ile birebir aynı olmalı
    let email: String
    let password: String
    let phone : String
    let cityId : Int  // API il numarası istiyor (zorunlu)
    let companyName : String? // ? = boş olabilir, boşsa JSON'a yazılmaz
    let kvkkAccepted : Bool
}

struct RegisterResponse : Decodable { // Decodable: gelen JSON'dan struct üretir
    
    let id : String
    let fullName : String
    let email : String
    let userType : String
    
}

struct APIErrorResponse : Decodable {
    
    let detail : String?  // API'nin yazdığı Türkçe hata mesajı
    let errors: [String: [String]]?   // alan adı → o alanın hata mesajları
}
/*
 - Gönderirken struct → JSON (Encodable).
 - Cevap gelirken JSON → struct (Decodable).
 - Hata gelirse (ör. "Bu e-posta zaten kayıtlı") mesajı detail'dan alıp ekranda göstereceğiz.
 */
