//
//  FavoritesViewModel.swift
//  Yukum
//

import Foundation
import Observation

// ┌─ BAĞLANTI HARİTASI: FavoritesViewModel ──────────────────────────────────────────
// │ EKRAN     : Views/FavoritesView | açan: Views/HomeView (Taşımacı, sol üst kalp ikonu)
// │ SERVİS    : ListingServicing → ListingService | API: GET /api/v1/listings/favorites · DELETE /api/v1/listings/{id}/favorite
// │ MODEL     : Listing (isFavorite hep true) | satıra basınca ListingDetailView açılır
// └──────────────────────────────────────────────────────────────────────

@Observable
final class FavoritesViewModel {
    private let service: ListingServicing

    var listings: [Listing] = [] // favori ve hâlâ açık ilanlar (son favorilenen üstte)
    var errorMessage: String?

    init(service: ListingServicing = ListingService()) { self.service = service }

    // load: favorileri çeker | ÇAĞIRAN: View .task ve .refreshable | ZİNCİR: ListingService.favorites → GET /api/v1/listings/favorites
    func load() async {
        errorMessage = nil
        do { listings = try await service.favorites() }
        catch { if let message = error.userMessage { errorMessage = message } }
    }

    // remove: satırı kaydırıp "Çıkar" | önce sunucuya "favori olmasın" der, başarılıysa listeyi yeniler
    // ZİNCİR: FavoritesView swipeActions → bu fonksiyon → ListingService.setFavorite(isFavorite: false) → DELETE /api/v1/listings/{id}/favorite → load()
    func remove(_ listing: Listing) async {
        errorMessage = nil
        do {
            try await service.setFavorite(listingId: listing.id, isFavorite: false)
            await load()
        } catch {
            if let message = error.userMessage { errorMessage = message }
        }
    }
}
