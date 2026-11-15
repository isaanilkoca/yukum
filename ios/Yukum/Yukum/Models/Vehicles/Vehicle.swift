//
//  Vehicle.swift
//  Yukum
//
//  Araçlarım (15 Kasım): Taşımacı'nın kayıtlı aracı + ekleme/düzenleme gövdesi.
//

import Foundation // [SWIFT] temel türler

// ┌─ BAĞLANTI HARİTASI: Vehicle ─────────────────────────────────────────
// │ GELEN  : GET /api/v1/vehicles → [Vehicle] (VehicleService.mine)
// │ GİDEN  : POST /api/v1/vehicles, PUT /api/v1/vehicles/{id} → VehicleBody
// │ SUNUCU : backend Application/Vehicles/VehicleHandlers.cs (plaka zorunlu + Türkiye biçimi, tek biçime çevrilir, aynı plaka iki kez yok)
// └──────────────────────────────────────────────────────────────────────

// ⮕ KULLANIM [Vehicle]: VehiclesViewModel, VehiclesView
struct Vehicle: Decodable, Identifiable, Equatable {
    let id: String
    let type: String          // VehicleType.rawValue ("Truck"...)
    let plateNumber: String   // sunucu tek biçime çevirir: "34 ABC 123"
    let capacityKg: Int?      // isteğe bağlı
    // 15 Kasım (kullanıcı: "yaşı, markası, modeli zorunlu; ilan veren görebilsin") | var + ? : eski kayıtta boş gelir → "bilgileri tamamla" uyarısı
    var brand: String? = nil
    var model: String? = nil
    var year: Int? = nil

    var typeTitle: String { VehicleType(rawValue: type)?.title ?? type } // "Tır", "Kamyon"... ⮕ VehicleType.swift
    // Marka/model/yıl dolu mu? (sunucu teklifte bunu arar: CreateOfferHandler → "aracın bilgilerini tamamla")
    var hasDetails: Bool { !(brand ?? "").isEmpty && !(model ?? "").isEmpty && year != nil }
    // "Mercedes-Benz Actros · 2019" | eksikse nil
    var detailsText: String? { hasDetails ? "\(brand!) \(model!) · \(year!)" : nil }
}

// Ekleme/düzenleme gövdesi | capacityKg nil → JSON'a yazılmaz (isteğe bağlı)
struct VehicleBody: Encodable { let type: String; let plateNumber: String; let capacityKg: Int?; let brand: String; let model: String; let year: Int } // marka/model/yıl: 15 Kasım, zorunlu

// Profilde görünen araç (15 Kasım) | API: CarrierProfileDto.vehicles (PublicVehicleDto) — PLAKA YOK
// ⮕ KULLANIM [PublicVehicle]: CarrierProfile.vehicles → CarrierProfileView
nonisolated struct PublicVehicle: Decodable, Hashable {
    let type: String
    let brand: String?
    let model: String?
    let year: Int?
    let capacityKg: Int?
    var typeTitle: String { VehicleType(rawValue: type)?.title ?? type }
}
