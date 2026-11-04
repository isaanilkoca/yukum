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

// ⮕ KULLANIM [CreateListingRequest]: kullanır: CreateListingViewModel › submit(), ListingService › create(), ListingServicing › create(), FakeListingService (test)
struct CreateListingRequest: Encodable { // Encodable [SWIFT]: JSON'a çevrilebilir
    // ⮕ KULLANIM [title]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let title: String
    // ⮕ KULLANIM [description]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let description: String? // String?: boş bırakılabilir (nil gider)
    // ⮕ KULLANIM [weightKg]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let weightKg: Int
    // ⮕ KULLANIM [vehicleType]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let vehicleType: String // "Truck", "Lorry"... (CreateListingView.vehicleTypes'taki ilk değer)
    // ⮕ KULLANIM [fromCityId]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let fromCityId: Int
    // ⮕ KULLANIM [fromDistrictId]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let fromDistrictId: Int
    // ⮕ KULLANIM [toCityId]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let toCityId: Int
    // ⮕ KULLANIM [toDistrictId]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let toDistrictId: Int
    // ⮕ KULLANIM [pickupDate]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let pickupDate: String // "2026-11-05" biçiminde; API tarih ister, saat değil
    // ⮕ KULLANIM [budget]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let budget: Int? // isteğe bağlı
    
}
