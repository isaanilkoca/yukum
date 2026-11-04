//
//  Listing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: Listing (ilan) ──────────────────────────────────────────────
// │ MODEL     : Tek bir ilan: başlık, rota (il/ilçe adları), ağırlık, tarih, bütçe, (Taşımacı için) benim teklifim ve uzaklık
// │ ÜRETEN    : Services/ListingService.myListings() (Yük Veren) ve openListings() (Taşımacı) ← Networking/APIClient JSON'u bu kalıba çevirir
// │ SAKLAYAN  : ViewModels/HomeViewModel.listings (liste) | ListingOffersViewModel.listing, ListingDetailViewModel.listing (tek ilan)
// │ GÖSTEREN  : Views/HomeView (List) → Views/ListingRow (satır) | Views/ListingDetailView | Views/ListingOffersView (başlık)
// │ HAZIR (Swift/Apple) [SWIFT] : Decodable, Identifiable, String, Int, Double
// │ BİZİM (bizim yazdığımız) [BİZİM] : türler: Listing | değişken/durumlar: id, title, weightKg, fromCityName, fromDistrictName, toCityName, toDistrictName, pickupDate, budget, myOfferAmount …
// └──────────────────────────────────────────────────────────────────────

// API'den gelen tek ilan (GET /api/v1/listings/mine listesindeki her eleman). Yalnız listede göstereceklerimizi aldık.
// BAĞLANTI: Services/ListingService.swift myListings() bu struct'ın listesini döner → Views/HomeView.swift'te liste olarak gösterilir
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
    let distanceKm: Double? // Taşımacı'nın konumu ile ilanın kalkış noktası arası kuş uçuşu mesafe (km) | ? = konum gönderilmediyse API null verir, nil olur | NE İŞE YARAR: satırda "12 km" yazmak | NEREDE: Views/ListingRow.swift | API'deki "distanceKm" ile aynı ad

}
