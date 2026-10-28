//
//  RegisterRequest.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import Foundation

// BU DOSYA NE İŞE YARAR?
// API ile konuşurken kullanılan "paketlerin" (form kağıtlarının) kalıpları burada durur.
// Ekranda doldurulan bilgi bir kalıba yazılır, sonra JSON'a çevrilip API'ye gider.
// Kalıp = struct. Kalıptan üretilen dolu örnek = "body" (mektubun içi).
//
// Kimin yazdığı: struct isimleri ve alan adları BİZİM; Encodable/Decodable ise Swift'in hazır kodu.
// KURAL: alan adları API'nin beklediği JSON alan adlarıyla BİREBİR aynı olmalı (fullName, email...).

// MARK: - Yük Veren kaydı (POST /api/v1/auth/register/shipper)

// Gönderdiğimiz paket (form kağıdı).
// Encodable = Swift'in hazır sözü: "bu struct JSON'a çevrilebilir" (JSONEncoder bunu kullanır).
struct RegisterRequest: Encodable {

    let fullName : String      // ad soyad
    let email: String
    let password: String
    let phone : String
    let cityId : Int           // API il numarası ister (zorunlu); Int = sayı, metin değil
    let companyName : String?  // ? = boş olabilir (isteğe bağlı); nil ise JSON'a hiç yazılmaz
    let kvkkAccepted : Bool    // KVKK onayı; true olmalı
}

// API'den dönen başarılı cevap (201). Şifre ve hash asla dönmez.
// Decodable = Swift'in hazır sözü: "gelen JSON'dan bu struct üretilebilir" (JSONDecoder bunu kullanır).
struct RegisterResponse : Decodable {

    let id : String        // yeni hesabın numarası
    let fullName : String
    let email : String
    let userType : String  // "Shipper" ya da "Carrier"
}

// API hata verince (400, 409...) gelen cevabın kalıbı; ekranda göstereceğimiz mesajı buradan okuruz.
struct APIErrorResponse : Decodable {

    let detail : String?              // genel Türkçe mesaj (örn. "Bu e-posta zaten kayıtlı")
    let errors: [String: [String]]?   // alan adı → o alanın hata mesajları (örn. "password": ["Şifre en az 8 karakter olmalı"])
}

// ÖZET:
// - Gönderirken: struct → JSON (Encodable)
// - Cevap gelirken: JSON → struct (Decodable)
// - Hata gelirse: mesaj APIErrorResponse içinden okunup ekranda gösterilir

// MARK: - Taşımacı kaydı (POST /api/v1/auth/register/carrier)

// Tek araç bilgisi; API'nin "vehicles" listesindeki her eleman böyle görünür.
struct VehicleRequest: Encodable {
    let type: String          // "Truck", "Lorry"... (Picker'daki tag değeri; yazımı API ile aynı olmalı)
    let plateNumber: String?  // plaka, isteğe bağlı; nil ise JSON'a yazılmaz
    let capacityKg: Int       // kapasite kg; sayı olarak gider, metin değil
}

// Taşımacı kayıt paketi.
// Not: Swift, struct oluştururken alanları BURADAKİ SIRAYLA ister; çağırırken aynı sırayı kullan.
struct RegisterCarrierRequest: Encodable {
    let fullName: String
    let email: String
    let password: String
    let phone: String
    let homeCityId: Int              // merkez il (şimdilik sabit 34)
    let vehicles: [VehicleRequest]   // [ ] = liste; en az 1 araç zorunlu
    let kvkkAccepted: Bool
}
// Cevap paketi Yük Veren ile aynı (RegisterResponse), yenisi gerekmez.
