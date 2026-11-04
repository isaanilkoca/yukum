//
//  District.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: District (ilçe) ─────────────────────────────────────────────
// │ MODEL     : Bir ilçe: id, ad
// │ ÜRETEN    : Features/Listings/CityService.districts(cityId:) ← GET /api/v1/cities/{id}/districts (il seçilince çekilir)
// │ SAKLAYAN  : Features/Listings/HomeViewModel.filterDistricts | Features/Listings/CreateListingViewModel.fromDistricts, toDistricts
// │ SEÇİM     : Picker'ın tag'i district.id → filterDistrictId / fromDistrictId / toDistrictId
// └──────────────────────────────────────────────────────────────────────

// KULLANAN: Features/Listings/CityService.swift districts(cityId:) → [District] döner | ilçe listesi seçilen ile göre CreateListingView'da gösterilecek
// ⮕ KULLANIM [District]: kullanır: CreateListingViewModel › fromDistricts, CreateListingViewModel › toDistricts, HomeViewModel › filterDistricts, CityService › districts(), CityServicing › districts(), CreateListingViewModelTests (test) … +2
struct District: Decodable, Identifiable { // Decodable [SWIFT]: JSON'dan bu türde değer üretilebilir | Identifiable [SWIFT]: benzersiz id'si var (List/ForEach'te id: yazmak gerekmez)
    // ⮕ KULLANIM [id]: okur: CreateListingView › body, HomeView › body
    let id: Int // ilçe numarası (ilanda fromDistrictId / toDistrictId olarak gidecek)
    // ⮕ KULLANIM [name]: okur: CreateListingView › body, HomeView › body
    let name: String // ekranda görünen ad
}
