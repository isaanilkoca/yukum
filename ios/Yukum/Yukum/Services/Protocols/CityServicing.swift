//
//  CityServicing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: CityServicing (sözleşme) ────────────────────────────────────
// │ GERÇEK    : Services/CityService.swift | SAHTE (test): YukumTests/Support/FakeCityService.swift
// │ KULLANAN  : ViewModels/HomeViewModel (filtre), ViewModels/CreateListingViewModel (Kalkış/Varış)
// └──────────────────────────────────────────────────────────────────────

protocol CityServicing {
    func cities() async throws -> [City]
    func districts(cityId: Int) async throws -> [District]
}
