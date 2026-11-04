//
//  VehicleRequest.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: VehicleRequest (araç) ───────────────────────────────────────
// │ MODEL     : Taşımacı kaydındaki tek araç bilgisi
// │ YOL       : Views/CarrierRegisterView araç alanları → CarrierRegisterViewModel.register() VehicleRequest'e çevirir → RegisterCarrierRequest.vehicles listesine konur → AuthService.registerCarrier | araç türü seçenekleri: Models/Vehicles/VehicleType.swift
// └──────────────────────────────────────────────────────────────────────

// Tek araç bilgisi; API'nin "vehicles" listesindeki her eleman böyle görünür.
// KULLANAN: Views/CarrierRegisterView.swift içinde "vehicle" değişkenine atanır, sonra RegisterCarrierRequest.vehicles listesine konur.
struct VehicleRequest: Encodable {
    let type: String          // "Truck", "Lorry"... (Picker'daki tag değeri; yazımı API ile aynı olmalı)
    let plateNumber: String?  // plaka, isteğe bağlı; nil ise JSON'a yazılmaz
    let capacityKg: Int       // kapasite kg; sayı olarak gider, metin değil
}
