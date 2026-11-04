//
//  CityServicing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: CityServicing (sözleşme) ────────────────────────────────────
// │ GERÇEK    : Services/CityService.swift | SAHTE (test): YukumTests/Support/FakeCityService.swift
// │ KULLANAN  : ViewModels/HomeViewModel (filtre), ViewModels/CreateListingViewModel (Kalkış/Varış)
// └──────────────────────────────────────────────────────────────────────

// ⮕ KULLANIM [CityServicing]: kullanır: CreateListingViewModel › cityService, CreateListingViewModel › init(), HomeViewModel › cityService, HomeViewModel › init(), CityService › districts(), FakeCityService (test)
protocol CityServicing { // protocol [SWIFT]: sözleşme: "bu fonksiyonlara sahip olan her şey bu sözleşmeyi karşılar"
    // ⮕ KULLANIM [cities]: çağırır: CreateListingViewModel › loadCities(), HomeViewModel › load()
    func cities() async throws -> [City] // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
    // ⮕ KULLANIM [districts]: çağırır: CreateListingViewModel › fromCityChanged(), CreateListingViewModel › toCityChanged(), HomeViewModel › cityFilterChanged()
    func districts(cityId: Int) async throws -> [District]
}
