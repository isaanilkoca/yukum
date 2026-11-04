//
//  RegisterRequest.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: RegisterRequest (Yük Veren kayıt paketi) ────────────────────
// │ MODEL     : Yük Veren kaydı için GİDEN paket
// │ DOLDURAN  : ViewModels/RegisterViewModel.register() (formdaki alanlardan; cityId şimdilik sabit 34)
// │ YOL       : Views/RegisterView → RegisterViewModel → Services/AuthService.register → POST /api/v1/auth/register/shipper
// │ CEVAP     : RegisterResponse
// │ HAZIR (Swift/Apple) [SWIFT] : Encodable, String, Int, Bool
// │ BİZİM (bizim yazdığımız) [BİZİM] : türler: RegisterRequest | değişken/durumlar: fullName, email, password, phone, cityId, companyName, kvkkAccepted
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA NE İŞE YARAR?
// API ile konuşurken kullanılan "paketlerin" (form kağıtlarının) kalıpları burada durur.
// Ekranda doldurulan bilgi bir kalıba yazılır, sonra JSON'a çevrilip API'ye gider.
// Kalıp = struct. Kalıptan üretilen dolu örnek = "body" (mektubun içi).
// Kimin yazdığı: struct isimleri ve alan adları BİZİM; Encodable/Decodable ise Swift'in hazır kodu.
// KURAL: alan adları API'nin beklediği JSON alan adlarıyla BİREBİR aynı olmalı (fullName, email...).
// MARK: - Yük Veren kaydı (POST /api/v1/auth/register/shipper)

// Gönderdiğimiz paket (form kağıdı).
// Encodable = Swift'in hazır sözü: "bu struct JSON'a çevrilebilir" (JSONEncoder bunu kullanır).
// KULLANAN: Views/RegisterView.swift paketi doldurur → AuthService.register gönderir.
struct RegisterRequest: Encodable { // Encodable [SWIFT]: bu türdeki değer JSON'a çevrilebilir

    let fullName : String      // ad soyad
    let email: String
    let password: String
    let phone : String
    let cityId : Int           // API il numarası ister (zorunlu); Int = sayı, metin değil
    let companyName : String?  // ? = boş olabilir (isteğe bağlı); nil ise JSON'a hiç yazılmaz
    let kvkkAccepted : Bool    // KVKK onayı; true olmalı
}
