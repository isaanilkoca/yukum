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
// ⮕ KULLANIM [VehicleRequest]: kullanır: CarrierRegisterViewModel › register(), RegisterCarrierRequest › vehicles
struct VehicleRequest: Encodable { // Encodable [SWIFT]: bu türdeki değer JSON'a çevrilebilir
    // ⮕ KULLANIM [type]: okur: CarrierRegisterViewModelTests (test)
    let type: String          // "Truck", "Lorry"... (Picker'daki tag değeri; yazımı API ile aynı olmalı)
    // ⮕ KULLANIM [plateNumber]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let plateNumber: String?  // plaka, isteğe bağlı; nil ise JSON'a yazılmaz
    // ⮕ KULLANIM [capacityKg]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let capacityKg: Int       // kapasite kg; sayı olarak gider, metin değil
}


