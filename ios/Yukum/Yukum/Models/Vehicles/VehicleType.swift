//
//  VehicleType.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: VehicleType (araç türü) ───────────────────────────────────────
// │ MODEL     : API'nin tanıdığı araç türleri: Truck, Lorry, Pickup, Refrigerated, Other (backend: VehicleType enum)
// │ KULLANAN  : ViewModels/CreateListingViewModel (ilan için istenen araç) | ViewModels/CarrierRegisterViewModel (kaydedilen araç)
// │ GÖSTEREN  : Views/CreateListingView ve Views/CarrierRegisterView araç Picker'ı → ForEach(VehicleType.allCases)
// │ NEDEN     : Bu liste eskiden iki ayrı yerde (ilan formu, taşımacı kaydı) kopya yazılıydı; artık TEK kaynak
// └──────────────────────────────────────────────────────────────────────

// enum [SWIFT]: sabit seçenek listesi | String: her seçeneğin bir yazı değeri var (rawValue) → API'ye giden değer
// CaseIterable [SWIFT]: allCases ile bütün seçenekleri liste olarak verir (Picker'ı otomatik doldurmak için)
// Identifiable [SWIFT]: ForEach'te id: yazmaya gerek kalmasın | id olarak rawValue kullanılır
enum VehicleType: String, CaseIterable, Identifiable {
    case truck = "Truck"
    case lorry = "Lorry"
    case pickup = "Pickup"
    case refrigerated = "Refrigerated"
    case other = "Other"

    var id: String { rawValue } // Identifiable'ın istediği benzersiz anahtar

    // title: ekranda görünen Türkçe ad | rawValue ise API'ye giden değerdir (Picker'da tag(type.rawValue))
    var title: String {
        switch self {
        case .truck: return "Tır"
        case .lorry: return "Kamyon"
        case .pickup: return "Kamyonet"
        case .refrigerated: return "Frigorifik"
        case .other: return "Diğer"
        }
    }
}
