//
//  RegisterCarrierRequest.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: RegisterCarrierRequest (Taşımacı kayıt paketi) ──────────────
// │ MODEL     : Taşımacı kaydı için GİDEN paket (içinde VehicleRequest listesi var)
// │ YOL       : Views/CarrierRegisterView → ViewModels/CarrierRegisterViewModel.register() → Services/AuthService.registerCarrier → POST /api/v1/auth/register/carrier
// │ CEVAP     : RegisterResponse
// └──────────────────────────────────────────────────────────────────────

// Taşımacı kayıt paketi.
// Not: Swift, struct oluştururken alanları BURADAKİ SIRAYLA ister; çağırırken aynı sırayı kullan.
// KULLANAN: Views/CarrierRegisterView.swift içinde "body" değişkenine atanır, AuthService.registerCarrier(body) ile API'ye gönderilir.
struct RegisterCarrierRequest: Encodable { // Encodable [SWIFT]: bu türdeki değer JSON'a çevrilebilir
    let fullName: String
    let email: String
    let password: String
    let phone: String
    let homeCityId: Int              // merkez il (şimdilik sabit 34)
    let vehicles: [VehicleRequest]   // [ ] = liste; en az 1 araç zorunlu
    let kvkkAccepted: Bool
}
// Cevap paketi Yük Veren ile aynı (RegisterResponse), yenisi gerekmez.
