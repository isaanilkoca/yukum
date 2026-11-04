//
//  ListingOffersViewModel.swift
//  Yukum
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: ListingOffersViewModel ──────────────────────────────────────
// │ EKRAN     : Views/ListingOffersView (@State private var viewModel, init(listing:)) — Yük Veren'in ilanına gelen BEKLEYEN teklifler; Views/HomeView listesindeki satır açar
// │ SERVİS    : Services/Protocols/OfferServicing → OfferService.listingOffers / decide | ListingServicing → ListingService.cancel
// │ MODEL     : Listing (hangi ilan), ListingOffer | sohbet için ChatContext
// │ AKIŞ      : View .task → load() → offers | Kabul/Reddet → decide() → load() | Kaldır → cancelListing() → true ise View kapanır
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: "Gelen Teklifler" (Yük Veren, bir ilanın BEKLEYEN teklifleri) ekranının durumu ve mantığı: liste, kabul/red kararı, ilanı yayından kaldırma
// BAĞLANTI: Views/ListingOffersView.swift kullanır | servisler: Services/OfferService.swift, Services/ListingService.swift | sohbet bilgisi: ViewModels/ChatContext.swift
// ⮕ KULLANIM [ListingOffersViewModel]: kullanır: ListingOffersView › viewModel, ListingOffersView › init(), ListingOffersViewModelTests (test)
@Observable // @Observable [SWIFT]: sınıfı gözlemlenebilir yapar: değişkenleri değişince onları okuyan ekranlar kendiliğinden yenilenir
final class ListingOffersViewModel {
    // ⮕ ZİNCİR: Views/ListingOffersView: başlık Text(viewModel.listing.title) | servis çağrılarında listing.id | gelen: Views/HomeView Yük Veren listesi → ListingOffersView(listing:)
    // ⮕ KULLANIM [listing]: okur: ListingOffersViewModel › load(), ListingOffersViewModel › cancelListing(), ListingOffersView › body
    let listing: Listing
    // ⮕ KULLANIM [offerService]: okur: ListingOffersViewModel › load(), ListingOffersViewModel › decide()
    private let offerService: OfferServicing
    // ⮕ KULLANIM [listingService]: okur: ListingOffersViewModel › cancelListing()
    private let listingService: ListingServicing

    // ⮕ ZİNCİR: Views/ListingOffersView: List(viewModel.offers) | DOLDURAN: load() ← OfferService.listingOffers | MODEL: [ListingOffer]
    // ⮕ KULLANIM [offers]: YAZAR: ListingOffersViewModel › load() | okur: ListingOffersView › body, ListingOffersViewModelTests (test)
    var offers: [ListingOffer] = []
    // ⮕ ZİNCİR: Views/ListingOffersView: if let errorMessage → kırmızı yazı
    // ⮕ KULLANIM [errorMessage]: YAZAR: ListingOffersViewModel › load(), ListingOffersViewModel › decide(), ListingOffersViewModel › cancelListing() | okur: ListingOffersViewModelTests (test)
    var errorMessage: String?
    // ⮕ ZİNCİR: Views/ListingOffersView: .navigationDestination(item: $viewModel.chat) { ChatView(context:) } | DOLDURAN: openChat(_:)
    // ⮕ KULLANIM [chat]: YAZAR: ListingOffersViewModel › openChat() | bağlar(okur+yazar): ListingOffersView › body
    var chat: ChatContext?

    init(listing: Listing, offerService: OfferServicing = OfferService(), listingService: ListingServicing = ListingService()) {
        self.listing = listing
        self.offerService = offerService
        self.listingService = listingService
    }

    // ⮕ ZİNCİR: Views/ListingOffersView: .task ve .refreshable | OfferService.listingOffers(listingId:)
    // ⮕ KULLANIM [load]: çağırır: ListingOffersViewModel › decide(), ListingOffersView › body
    func load() async { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz)
        errorMessage = nil
        do { offers = try await offerService.listingOffers(listingId: listing.id) } // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
        catch { if let message = error.userMessage { errorMessage = message } }
    }

    // decide: Kabul Et / Reddet | kabulde ilan atanır ve diğer bekleyen teklifler reddedilir (sunucu yapar) → liste yenilenir
    // ⮕ ZİNCİR: Views/ListingOffersView: "Kabul et"/"Reddet" → Task { await viewModel.decide(offer, accept:) } | OfferService.decide(offerId:accept:) sonra load() (kabulde ilan atanır, diğer bekleyenler reddedilir: sunucu yapar)
    // ⮕ KULLANIM [decide]: çağırır: ListingOffersViewModel › decide(), ListingOffersView › body, ListingOffersViewModelTests (test)
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
    // ⮕ ZİNCİR: Views/ListingOffersView: sağ üst "Kaldır" → alert "Yayından Kaldır" | ListingService.cancel(listingId:) | true dönerse View dismiss() ile HomeView'a döner
    // ⮕ KULLANIM [cancelListing]: çağırır: ListingOffersView › body, ListingOffersViewModelTests (test)
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

    // ⮕ ZİNCİR: Views/ListingOffersView: Button("Sohbet") { viewModel.openChat(offer) } | chat = ChatContext.forShipperPending(offer)
    // ⮕ KULLANIM [openChat]: çağırır: ListingOffersView › body
    func openChat(_ offer: ListingOffer) { chat = ChatContext.forShipperPending(offer) }
}
