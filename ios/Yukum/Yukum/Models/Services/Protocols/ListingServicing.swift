//
//  ListingServicing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: ListingServicing (sözleşme) ─────────────────────────────────
// │ GERÇEK    : Models/Services/ListingService.swift | SAHTE (test): YukumTests/Support/FakeListingService.swift
// │ KULLANAN  : ViewModels/HomeViewModel, CreateListingViewModel, ListingOffersViewModel (servise değil bu sözleşmeye bağlıdırlar)
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA: servislerin "ne yapabildiğini" anlatan SÖZLEŞMELER (protocol).
// NEDEN: ViewModel'ler somut servise (ListingService) değil, sözleşmeye (ListingServicing) bağlı olur.
//   → gerçek uygulamada gerçek servis verilir, TESTTE sahte servis verilir (internet/sunucu gerekmez). Buna BAĞIMLILIK ENJEKSİYONU (Dependency Injection) denir.
// protocol [SWIFT]: "bu fonksiyonlara sahip olan her şey bu sözleşmeyi karşılar" | adlandırma: yaptığı işin sıfat hâli (...Servicing)
// BAĞLANTI: ViewModels/*.swift sözleşmeleri kullanır | gerçek servisler Services/*Service.swift (aşağıdaki extension'lar onları sözleşmeye bağlar) | sahte servisler YukumTests/Support/

// ⮕ KULLANIM [ListingServicing]: kullanır: CreateListingViewModel › listingService, CreateListingViewModel › init(), HomeViewModel › listingService, HomeViewModel › init(), ListingOffersViewModel › listingService, ListingOffersViewModel › init() … +2
protocol ListingServicing {
    // ⮕ KULLANIM [create]: çağırır: CreateListingViewModel › submit()
    func create(_ body: CreateListingRequest) async throws -> ListingResponse // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
    // ⮕ KULLANIM [myListings]: çağırır: HomeViewModel › load()
    func myListings() async throws -> [Listing]
    func allMyListings() async throws -> [Listing] // 15 Kasım: profil > İlanlarım (?all=true)
    
    // ⮕ KULLANIM [openListings]: çağırır: HomeViewModel › load()
    func openListings(filter: OpenListingsFilter, page: Int, lat: Double?, lon: Double?) async throws -> Page<Listing>    // ⮕ KULLANIM [cancel]: çağırır: ListingOffersViewModel › cancelListing(), ChatViewModelTests (test)
    
    func cancel(listingId: String) async throws
    // priceReference: bir rotanın emsal fiyatı (medyan) | ÇAĞIRAN: ListingDetailViewModel.loadReference() | API: GET /api/v1/price-reference
    // setFavorite: favoriler / favoriden çıkarır | ÇAĞIRAN: ListingDetailViewModel.toggleFavorite(), FavoritesViewModel.remove() | API: PUT / DELETE /api/v1/listings/{id}/favorite
    func setFavorite(listingId: String, isFavorite: Bool) async throws
    // favorites: Taşımacı'nın favori (ve hâlâ açık) ilanları | ÇAĞIRAN: FavoritesViewModel.load() | API: GET /api/v1/listings/favorites
    func favorites() async throws -> [Listing]
    // recordView: ilan detayı açıldı | ÇAĞIRAN: ListingDetailViewModel.recordView() | API: POST /api/v1/listings/{id}/view
    func recordView(listingId: String) async throws
    // stats: ilan sahibinin sayıları | ÇAĞIRAN: ListingOffersViewModel.loadStats() | API: GET /api/v1/listings/{id}/stats
    func stats(listingId: String) async throws -> ListingStats
    func priceReference(fromCityId: Int, toCityId: Int, vehicleType: String) async throws -> PriceReference
    // İlanı günceller | body: ilan açmayla aynı paket (aynı kurallar) | API: PUT /api/v1/listings/{id}
    // ZİNCİR: CreateListingViewModel.submit() (düzenleme modu) → bu sözleşme → ListingService.update
    func update(listingId: String, _ body: CreateListingRequest) async throws -> ListingResponse
}
