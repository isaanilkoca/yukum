//
//  Listing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: Listing (ilan) ──────────────────────────────────────────────
// │ MODEL     : Tek bir ilan: başlık, rota (il/ilçe adları), ağırlık, tarih, bütçe, (Taşımacı için) benim teklifim ve uzaklık
// │ ÜRETEN    : Models/Services/ListingService.myListings() (Yük Veren) ve openListings() (Taşımacı) ← Models/Networking/APIClient JSON'u bu kalıba çevirir
// │ SAKLAYAN  : ViewModels/HomeViewModel.listings (liste) | ListingOffersViewModel.listing, ListingDetailViewModel.listing (tek ilan)
// │ GÖSTEREN  : Views/HomeView (List) → Views/ListingRow (satır) | Views/ListingDetailView | Views/ListingOffersView (başlık)
// └──────────────────────────────────────────────────────────────────────

// API'den gelen tek ilan (GET /api/v1/listings/mine listesindeki her eleman). Yalnız listede göstereceklerimizi aldık.
// BAĞLANTI: Models/Services/ListingService.swift myListings() bu struct'ın listesini döner → Views/HomeView.swift'te liste olarak gösterilir
// ⮕ KULLANIM [Listing]: kullanır: HomeViewModel › listings, ListingDetailViewModel › listing, ListingDetailViewModel › init(), ListingOffersViewModel › listing, ListingOffersViewModel › init(), ListingDetailView › init() … +10
struct Listing: Decodable, Identifiable { // Decodable [SWIFT]: gelen JSON'dan üretilebilir | Identifiable [SWIFT]: benzersiz id'si var, ForEach'te id: yazmak gerekmez
    // ⮕ KULLANIM [id]: okur: ListingDetailViewModel › submit(), ListingOffersViewModel › load(), ListingOffersViewModel › cancelListing()
    let id: String // ilan numarası (GUID yazı olarak gelir) | Identifiable bunu kullanır
    // ⮕ KULLANIM [title]: okur: ListingDetailView › body, ListingOffersView › body, ListingRow › body
    let title: String // başlık
    // ⮕ KULLANIM [weightKg]: okur: ListingDetailView › body, ListingRow › body
    let weightKg: Int // ağırlık
    // ⮕ KULLANIM [fromCityName]: okur: ListingDetailView › body, ListingRow › body
    let fromCityName: String // kalkış ili adı (backend ekledi)
    // ⮕ KULLANIM [fromDistrictName]: okur: ListingDetailView › body
    let fromDistrictName: String // kalkış ilçesi adı | API'den "fromDistrictName" olarak gelir, adı birebir aynı olmalı yoksa okuma hatası verir
    // ⮕ KULLANIM [toCityName]: okur: ListingDetailView › body, ListingRow › body
    let toCityName: String // varış ili adı
    // ⮕ KULLANIM [toDistrictName]: okur: ListingDetailView › body
    let toDistrictName: String // varış ilçesi adı
    // ⮕ KULLANIM [pickupDate]: okur: ListingDetailView › body, ListingRow › body
    let pickupDate: String // "2026-10-31" yazısı olarak gelir, ekranda olduğu gibi göstereceğiz
    // ⮕ KULLANIM [budget]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let budget: Double? // Double: ondalıklı sayı (API 50000.0 gönderir) | ?: isteğe bağlı, yoksa nil
    // ⮕ KULLANIM [myOfferAmount]: okur: ListingDetailViewModel › hasExistingOffer, ListingDetailView › body, ListingRow › body
    let myOfferAmount: Double? // bu Taşımacı'nın bu ilana verdiği teklif | ?: vermediyse nil | yalnız Taşımacı listesinde dolu gelir
    // ⮕ KULLANIM [myOfferStatus]: okur: ListingRow › body
    let myOfferStatus: String? // bu Taşımacı'nın teklifinin durumu: "Pending" / "Rejected" | ?: teklif vermediyse nil | API'deki "myOfferStatus" ile aynı ad    
    // ⮕ KULLANIM [distanceKm]: okur: ListingRow › body
    let distanceKm: Double? // Taşımacı'nın konumu ile ilanın kalkış noktası arası kuş uçuşu mesafe (km) | ? = konum gönderilmediyse API null verir, nil olur | NE İŞE YARAR: satırda "12 km" yazmak | NEREDE: Views/ListingRow.swift | API'deki "distanceKm" ile aynı ad

}
