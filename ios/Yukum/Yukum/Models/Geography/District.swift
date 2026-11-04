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
// ⮕ KULLANIM [District]: kullanır: CreateListingViewModel › fromDistricts, CreateListingViewModel › toDistricts, HomeViewModel › filterDistricts, CityService › districts(), CityServicing › districts(), CreateListingViewModelTests (test) … +2
struct District: Decodable, Identifiable { // Decodable [SWIFT]: JSON'dan bu türde değer üretilebilir | Identifiable [SWIFT]: benzersiz id'si var (List/ForEach'te id: yazmak gerekmez)
    // ⮕ KULLANIM [id]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let id: Int // ilçe numarası (ilanda fromDistrictId / toDistrictId olarak gidecek)
    // ⮕ KULLANIM [name]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let name: String // ekranda görünen ad
}
