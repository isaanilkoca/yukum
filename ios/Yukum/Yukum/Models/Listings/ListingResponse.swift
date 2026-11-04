//
//  ListingResponse.swift
//  Yukum
//

import Foundation

// API'den dönen oluşturulmuş ilan (201). Yalnız ihtiyacımız olan alanları aldık, Swift fazlasını yok sayar.
// BAĞLANTI: Services/ListingService.swift create() bu pakete çevirip geri döner → Views/CreateListingView.swift okur
struct ListingResponse: Decodable { // Decodable [SWIFT]: gelen JSON'dan üretilebilir
    let id: String // ilan numarası (GUID yazı olarak gelir)
    let title: String
}
