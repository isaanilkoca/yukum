//
//  District.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: District (ilçe) ─────────────────────────────────────────────
// │ MODEL     : Bir ilçe: id, ad
// │ ÜRETEN    : Services/CityService.districts(cityId:) ← GET /api/v1/cities/{id}/districts (il seçilince çekilir)
// │ SAKLAYAN  : ViewModels/HomeViewModel.filterDistricts | ViewModels/CreateListingViewModel.fromDistricts, toDistricts
// │ SEÇİM     : Picker'ın tag'i district.id → filterDistrictId / fromDistrictId / toDistrictId
// └──────────────────────────────────────────────────────────────────────

// KULLANAN: Services/CityService.swift districts(cityId:) → [District] döner | ilçe listesi seçilen ile göre CreateListingView'da gösterilecek
struct District: Decodable, Identifiable { // Decodable [SWIFT]: JSON'dan bu türde değer üretilebilir | Identifiable [SWIFT]: benzersiz id'si var (List/ForEach'te id: yazmak gerekmez)
    let id: Int // ilçe numarası (ilanda fromDistrictId / toDistrictId olarak gidecek)
    let name: String // ekranda görünen ad
}
