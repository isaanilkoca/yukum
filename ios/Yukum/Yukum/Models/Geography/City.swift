//
//  City.swift
//  Yukum
//

import Foundation

// BU DOSYA NE İŞE YARAR? API'den gelen il ve ilçe kayıtlarının kalıbı (form kağıdı). Sadece kalıp; çekme işini CityService yapar.
// API'nin her il/ilçe elemanı: {"id":34,"name":"İstanbul"} → aşağıdaki struct'a çevrilir.
// Decodable [SWIFT]: JSON'dan üretilebilir | Identifiable [SWIFT]: benzersiz id'si var (listelerde ForEach için gerekli)
// KURAL: alan adları API ile birebir aynı (id, name), yoksa okunamaz.
// BAĞLANTI (akış): CityService.cities() API'den JSON çeker → bu dosyadaki City dizisine çevirir → CreateListingView'daki "cities" değişkenine yazar → açılır listede gösterilir.

// KULLANAN: Services/CityService.swift ([City] döner) | Views/CreateListingView.swift (@State cities: [City], Picker'da gösterilir)
struct City: Decodable,Identifiable {

    let id : Int // plaka kodu (İstanbul = 34); ilan ve kayıt bunu API'ye cityId olarak gönderir
    let name : String  // ekranda görünen ad

}
