//
//  ListingRequest.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 30.10.2026.
//

import Foundation

// BU DOSYA NE İŞE YARAR? İlan açarken API'ye giden paket (CreateListingRequest) ve dönen ilan (ListingResponse).
// KURAL: alan adları API'nin JSON alan adlarıyla BİREBİR aynı olmalı.
// BAĞLANTI: View/CreateListingView.swift paketi doldurur → Network/ListingService.swift gönderir. API tarafı: backend ListingsController

struct CreateListingRequest: Encodable { // Encodable [SWIFT]: JSON'a çevrilebilir
    let title: String
    let description: String? // String?: boş bırakılabilir (nil gider)
    let weightKg: Int
    let vehicleType: String // "Truck", "Lorry"... (CreateListingView.vehicleTypes'taki ilk değer)
    let fromCityId: Int
    let fromDistrictId: Int
    let toCityId: Int
    let toDistrictId: Int
    let pickupDate: String // "2026-11-05" biçiminde; API tarih ister, saat değil
    let budget: Int? // isteğe bağlı
    
}



// API'den dönen oluşturulmuş ilan (201). Yalnız ihtiyacımız olan alanları aldık, Swift fazlasını yok sayar.
// BAĞLANTI: Network/ListingService.swift create() bu pakete çevirip geri döner → View/CreateListingView.swift okur
struct ListingResponse: Decodable { // Decodable [SWIFT]: gelen JSON'dan üretilebilir
    let id: String // ilan numarası (GUID yazı olarak gelir)
    let title: String
}



// API'den gelen tek ilan (GET /api/v1/listings/mine listesindeki her eleman). Yalnız listede göstereceklerimizi aldık.
// BAĞLANTI: Network/ListingService.swift myListings() bu struct'ın listesini döner → View/HomeView.swift'te liste olarak gösterilir
struct MyListing: Decodable, Identifiable { // Decodable [SWIFT]: gelen JSON'dan üretilebilir | Identifiable [SWIFT]: benzersiz id'si var, ForEach'te id: yazmak gerekmez
    let id: String // ilan numarası (GUID yazı olarak gelir) | Identifiable bunu kullanır
    let title: String // başlık
    let weightKg: Int // ağırlık
    let fromCityName: String // kalkış ili adı (backend ekledi)
    let toCityName: String // varış ili adı
    let pickupDate: String // "2026-10-31" yazısı olarak gelir, ekranda olduğu gibi göstereceğiz
    let budget: Double? // Double: ondalıklı sayı (API 50000.0 gönderir) | ?: isteğe bağlı, yoksa nil
}
