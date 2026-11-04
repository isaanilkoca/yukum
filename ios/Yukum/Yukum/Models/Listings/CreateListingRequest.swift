//
//  CreateListingRequest.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: CreateListingRequest (ilan verme paketi) ────────────────────
// │ MODEL     : İlan açmak için GİDEN paket
// │ DOLDURAN  : ViewModels/CreateListingViewModel.submit() (formdaki alanlardan; tarih "yyyy-MM-dd" yazıya çevrilir)
// │ YOL       : Views/CreateListingView → CreateListingViewModel → Services/ListingService.create → POST /api/v1/listings
// │ CEVAP     : ListingResponse
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA NE İŞE YARAR? İlan açarken API'ye giden paket (CreateListingRequest) ve dönen ilan (ListingResponse).
// KURAL: alan adları API'nin JSON alan adlarıyla BİREBİR aynı olmalı.
// BAĞLANTI: Views/CreateListingView.swift paketi doldurur → Services/ListingService.swift gönderir. API tarafı: backend ListingsController
// API'den gelen tek ilan (hem GET /listings/mine hem GET /listings listelerindeki her eleman). Yalnız listede göstereceklerimizi aldık.
// BAĞLANTI: Services/ListingService.swift myListings() ve openListings() bu struct'ın listesini döner → Views/HomeView.swift'te liste olarak gösterilir

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
