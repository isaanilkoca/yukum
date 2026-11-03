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

// API'den gelen tek ilan (hem GET /listings/mine hem GET /listings listelerindeki her eleman). Yalnız listede göstereceklerimizi aldık.
// BAĞLANTI: Network/ListingService.swift myListings() ve openListings() bu struct'ın listesini döner → View/HomeView.swift'te liste olarak gösterilir


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
struct Listing: Decodable, Identifiable { // Decodable [SWIFT]: gelen JSON'dan üretilebilir | Identifiable [SWIFT]: benzersiz id'si var, ForEach'te id: yazmak gerekmez
    let id: String // ilan numarası (GUID yazı olarak gelir) | Identifiable bunu kullanır
    let title: String // başlık
    let weightKg: Int // ağırlık
    let fromCityName: String // kalkış ili adı (backend ekledi)
    let fromDistrictName: String // kalkış ilçesi adı | API'den "fromDistrictName" olarak gelir, adı birebir aynı olmalı yoksa okuma hatası verir
    let toCityName: String // varış ili adı
    let toDistrictName: String // varış ilçesi adı
    let pickupDate: String // "2026-10-31" yazısı olarak gelir, ekranda olduğu gibi göstereceğiz
    let budget: Double? // Double: ondalıklı sayı (API 50000.0 gönderir) | ?: isteğe bağlı, yoksa nil
    let myOfferAmount: Double? // bu Taşımacı'nın bu ilana verdiği teklif | ?: vermediyse nil | yalnız Taşımacı listesinde dolu gelir
    let myOfferStatus: String? // bu Taşımacı'nın teklifinin durumu: "Pending" / "Rejected" | ?: teklif vermediyse nil | API'deki "myOfferStatus" ile aynı ad    
    let distanceKm: Double? // Taşımacı'nın konumu ile ilanın kalkış noktası arası kuş uçuşu mesafe (km) | ? = konum gönderilmediyse API null verir, nil olur | NE İŞE YARAR: satırda "12 km" yazmak | NEREDE: View/ListingRow.swift | API'deki "distanceKm" ile aynı ad

}


