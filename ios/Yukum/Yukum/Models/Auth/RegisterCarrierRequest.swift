//
//  RegisterCarrierRequest.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: RegisterCarrierRequest (Taşımacı kayıt paketi) ──────────────
// │ MODEL     : Taşımacı kaydı için GİDEN paket (içinde VehicleRequest listesi var)
// │ YOL       : Views/CarrierRegisterView → ViewModels/CarrierRegisterViewModel.register() → Models/Services/AuthService.registerCarrier → POST /api/v1/auth/register/carrier
// │ CEVAP     : RegisterResponse
// └──────────────────────────────────────────────────────────────────────

// Taşımacı kayıt paketi.
// Not: Swift, struct oluştururken alanları BURADAKİ SIRAYLA ister; çağırırken aynı sırayı kullan.
// KULLANAN: Views/CarrierRegisterView.swift içinde "body" değişkenine atanır, AuthService.registerCarrier(body) ile API'ye gönderilir.
// ⮕ KULLANIM [RegisterCarrierRequest]: kullanır: CarrierRegisterViewModel › register(), AuthService › registerCarrier(), AuthServicing › registerCarrier(), FakeAuthService (test)
struct RegisterCarrierRequest: Encodable { // Encodable [SWIFT]: bu türdeki değer JSON'a çevrilebilir
    // ⮕ KULLANIM [fullName]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let fullName: String
    // ⮕ KULLANIM [email]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let email: String
    // ⮕ KULLANIM [password]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let password: String
    // ⮕ KULLANIM [phone]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let phone: String
    // ⮕ KULLANIM [homeCityId]: okur: CarrierRegisterViewModelTests (test)
    let homeCityId: Int              // merkez il (şimdilik sabit 34)
    // ⮕ KULLANIM [vehicles]: okur: CarrierRegisterViewModelTests (test)
    let vehicles: [VehicleRequest]   // [ ] = liste; en az 1 araç zorunlu
    // ⮕ KULLANIM [kvkkAccepted]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let kvkkAccepted: Bool
}
// Cevap paketi Yük Veren ile aynı (RegisterResponse), yenisi gerekmez.
