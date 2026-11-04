//
//  RegisterRequest.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: RegisterRequest (Yük Veren kayıt paketi) ────────────────────
// │ MODEL     : Yük Veren kaydı için GİDEN paket
// │ DOLDURAN  : ViewModels/RegisterViewModel.register() (formdaki alanlardan; cityId şimdilik sabit 34)
// │ YOL       : Views/RegisterView → RegisterViewModel → Models/Services/AuthService.register → POST /api/v1/auth/register/shipper
// │ CEVAP     : RegisterResponse
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
// ⮕ KULLANIM [RegisterRequest]: kullanır: RegisterViewModel › register(), AuthService › register(), AuthServicing › register(), FakeAuthService (test)
struct RegisterRequest: Encodable { // Encodable [SWIFT]: bu türdeki değer JSON'a çevrilebilir

    // ⮕ KULLANIM [fullName]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let fullName : String      // ad soyad
    // ⮕ KULLANIM [email]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let email: String
    // ⮕ KULLANIM [password]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let password: String
    // ⮕ KULLANIM [phone]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let phone : String
    // ⮕ KULLANIM [cityId]: okur: RegisterViewModelTests (test)
    let cityId : Int           // API il numarası ister (zorunlu); Int = sayı, metin değil
    // ⮕ KULLANIM [companyName]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let companyName : String?  // ? = boş olabilir (isteğe bağlı); nil ise JSON'a hiç yazılmaz
    // ⮕ KULLANIM [kvkkAccepted]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let kvkkAccepted : Bool    // KVKK onayı; true olmalı
}
