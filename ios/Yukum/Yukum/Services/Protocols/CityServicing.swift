//
//  CityServicing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: CityServicing (sözleşme) ────────────────────────────────────
// │ GERÇEK    : Services/CityService.swift | SAHTE (test): YukumTests/Support/FakeCityService.swift
// │ KULLANAN  : ViewModels/HomeViewModel (filtre), ViewModels/CreateListingViewModel (Kalkış/Varış)
// └──────────────────────────────────────────────────────────────────────

protocol CityServicing { // protocol [SWIFT]: sözleşme: "bu fonksiyonlara sahip olan her şey bu sözleşmeyi karşılar"
    func cities() async throws -> [City] // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
    func districts(cityId: Int) async throws -> [District]
}
