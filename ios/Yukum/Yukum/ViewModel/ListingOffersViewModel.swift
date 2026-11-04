//
//  ListingOffersViewModel.swift
//  Yukum
//

import Foundation
import Observation

// BU SINIF: "Gelen Teklifler" (Yük Veren, bir ilanın BEKLEYEN teklifleri) ekranının durumu ve mantığı: liste, kabul/red kararı, ilanı yayından kaldırma
// BAĞLANTI: View/ListingOffersView.swift kullanır | servisler: Network/OfferService.swift, Network/ListingService.swift | sohbet bilgisi: ViewModel/ChatContext.swift
@Observable
final class ListingOffersViewModel {
    let listing: Listing
    private let offerService: OfferServicing
    private let listingService: ListingServicing

    var offers: [ListingOffer] = []
    var errorMessage: String?
    var chat: ChatContext?

    init(listing: Listing, offerService: OfferServicing = OfferService(), listingService: ListingServicing = ListingService()) {
        self.listing = listing
        self.offerService = offerService
        self.listingService = listingService
    }

    func load() async {
        errorMessage = nil
        do { offers = try await offerService.listingOffers(listingId: listing.id) }
        catch { if let message = error.userMessage { errorMessage = message } }
    }

    // decide: Kabul Et / Reddet | kabulde ilan atanır ve diğer bekleyen teklifler reddedilir (sunucu yapar) → liste yenilenir
    func decide(_ offer: ListingOffer, accept: Bool) async {
        errorMessage = nil
        do {
            try await offerService.decide(offerId: offer.id, accept: accept)
            await load()
        } catch {
            if let message = error.userMessage { errorMessage = message } // örn. "Bu teklif için karar zaten verilmiş."
        }
    }

    // cancelListing: ilanı yayından kaldırır | -> Bool: başarılı mı (ekran başarılıysa geri döner)
    func cancelListing() async -> Bool {
        errorMessage = nil
        do {
            try await listingService.cancel(listingId: listing.id)
            return true
        } catch {
            if let message = error.userMessage { errorMessage = message } // örn. "Bu ilan zaten tamamlanmış ya da kaldırılmış."
            return false
        }
    }

    func openChat(_ offer: ListingOffer) { chat = ChatContext.forShipperPending(offer) }
}
