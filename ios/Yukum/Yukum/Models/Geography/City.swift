//
//  City.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: City (il) ───────────────────────────────────────────────────
// │ MODEL     : Bir il: id = plaka kodu (34 İstanbul), ad
// │ ÜRETEN    : Models/Services/CityService.cities ← GET /api/v1/cities (herkese açık)
// │ SAKLAYAN  : ViewModels/HomeViewModel.cities (filtre Picker'ı) | ViewModels/CreateListingViewModel.cities (Kalkış/Varış İli Picker'ları)
// │ SEÇİM     : Picker'ın tag'i city.id → filterCityId / fromCityId / toCityId değişkenine yazılır
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA NE İŞE YARAR? API'den gelen il ve ilçe kayıtlarının kalıbı (form kağıdı). Sadece kalıp; çekme işini CityService yapar.
// API'nin her il/ilçe elemanı: {"id":34,"name":"İstanbul"} → aşağıdaki struct'a çevrilir.
// Decodable [SWIFT]: JSON'dan üretilebilir | Identifiable [SWIFT]: benzersiz id'si var (listelerde ForEach için gerekli)
// KURAL: alan adları API ile birebir aynı (id, name), yoksa okunamaz.
// BAĞLANTI (akış): CityService.cities() API'den JSON çeker → bu dosyadaki City dizisine çevirir → CreateListingView'daki "cities" değişkenine yazar → açılır listede gösterilir.

// KULLANAN: Models/Services/CityService.swift ([City] döner) | Views/CreateListingView.swift (@State cities: [City], Picker'da gösterilir)
// ⮕ KULLANIM [City]: kullanır: CreateListingViewModel › cities, HomeViewModel › cities, CityService › cities(), CityServicing › cities(), CreateListingViewModelTests (test), HomeViewModelTests (test) … +1
struct City: Decodable,Identifiable {

    // ⮕ KULLANIM [id]: okur: CreateListingView › body, HomeView › body
    let id : Int // plaka kodu (İstanbul = 34); ilan ve kayıt bunu API'ye cityId olarak gönderir
    // ⮕ KULLANIM [name]: okur: CreateListingView › body, HomeView › body
    let name : String  // ekranda görünen ad

}
