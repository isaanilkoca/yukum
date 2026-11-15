//
//  MyListingsViewModel.swift
//  Yukum
//
//  İlanlarım (15 Kasım, 8. adım): Yük Veren'in TÜM ilanları (açık + atanmış + tamamlanmış + kaldırılmış), profil sayfasından.
//

import Foundation  // [SWIFT] temel türler
import Observation // [SWIFT] @Observable

// ┌─ BAĞLANTI HARİTASI: MyListingsViewModel ─────────────────────────────────────
// │ EKRAN   : Views/MyListingsView ← ProfileView (Yük Veren)
// │ SERVİS  : ListingServicing.allMyListings → GET /api/v1/listings/mine?all=true → GetMyListingsHandler (IncludeClosed) → Listings tablosu
// │ FARK    : ana ekran yalnız AÇIK ilanları gösterir (myListings); burası geçmişi de durum rozetiyle gösterir
// └──────────────────────────────────────────────────────────────────────
@MainActor
@Observable
final class MyListingsViewModel {
    private let service: ListingServicing
    init(service: ListingServicing = ListingService()) { self.service = service }

    var listings: [Listing] = []
    var errorMessage: String?
    var loaded = false

    func load() async {
        errorMessage = nil
        do { listings = try await service.allMyListings() }
        catch { if let message = error.userMessage { errorMessage = message } }
        loaded = true
    }

    // Durum → rozet (yazı, simge, renk anahtarı) | sunucu: ListingStatus enum adı
    nonisolated static func badge(for status: String?) -> (text: String, icon: String, tone: Tone) {
        switch status {
        case "Assigned": return ("Taşımacı atandı", "truck.box.fill", .accent)
        case "Completed": return ("Tamamlandı", "checkmark.seal.fill", .success)
        case "Cancelled": return ("Kaldırıldı", "xmark.circle.fill", .danger)
        default: return ("Yayında", "dot.radiowaves.left.and.right", .accent)
        }
    }
    enum Tone { case accent, success, danger }
}
