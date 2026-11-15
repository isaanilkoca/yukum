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
// ⮕ KULLANIM [VehicleType]: kullanır: CarrierRegisterView › body, CreateListingView › body, CarrierRegisterViewModelTests (test), VehicleTypeTests (test)
enum VehicleType: String, CaseIterable, Identifiable {
    // ⮕ KULLANIM [truck]: okur: CarrierRegisterViewModelTests (test)
    case truck = "Truck"
    // ⮕ KULLANIM [lorry]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    case lorry = "Lorry"
    // ⮕ KULLANIM [pickup]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    case pickup = "Pickup"
    // ⮕ KULLANIM [refrigerated]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    case refrigerated = "Refrigerated"
    // ⮕ KULLANIM [other]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    case other = "Other"
    // 15 Kasım (kullanıcı: "küçük paketi şahsi arabasıyla da götürebilir") | backend VehicleType.Car = 5
    case car = "Car"
    // 15 Kasım (kullanıcı: "Yük Veren illa birini seçmek zorunda olmasın") | YALNIZ İLANDA: her araçtaki Taşımacı görür | backend VehicleType.Any = 100
    case any = "Any"

    // ⮕ KULLANIM [id]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    var id: String { rawValue } // Identifiable'ın istediği benzersiz anahtar

    // title: ekranda görünen Türkçe ad | rawValue ise API'ye giden değerdir (Picker'da tag(type.rawValue))
    // ⮕ KULLANIM [title]: okur: VehicleTypeTests (test)
    var title: String {
        switch self {
        case .truck: return "Tır"
        case .lorry: return "Kamyon"
        case .pickup: return "Kamyonet"
        case .refrigerated: return "Frigorifik (soğutuculu)" // 15 Kasım: "Frigorifik" tek başına anlaşılmıyordu
        case .car: return "Otomobil (şahsi araç)"
        case .other: return "Diğer"
        case .any: return "Farketmez"
        }
    }

    // 15 Kasım: iki ayrı liste — "Farketmez" bir aracın türü OLAMAZ (sunucu da reddeder), yalnız ilanın isteği olabilir
    // listingOptions: ilan ver ekranı (CreateListingView) — "Farketmez" en başta ve varsayılan
    static var listingOptions: [VehicleType] { [.any, .truck, .lorry, .pickup, .refrigerated, .car, .other] }
    // vehicleOptions: Araçlarım (VehicleFormSheet) ve Taşımacı filtresi (OpenListingsFilterView) — Farketmez yok
    static var vehicleOptions: [VehicleType] { [.truck, .lorry, .pickup, .refrigerated, .car, .other] }
}
