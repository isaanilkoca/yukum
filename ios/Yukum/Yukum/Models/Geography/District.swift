//
//  District.swift
//  Yukum
//

import Foundation

// KULLANAN: Services/CityService.swift districts(cityId:) → [District] döner | ilçe listesi seçilen ile göre CreateListingView'da gösterilecek
struct District: Decodable, Identifiable {
    let id: Int // ilçe numarası (ilanda fromDistrictId / toDistrictId olarak gidecek)
    let name: String // ekranda görünen ad
}
