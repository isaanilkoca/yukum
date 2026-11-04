//
//  OldOffersViewModel.swift
//  Yukum
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: OldOffersViewModel ──────────────────────────────────────────
// │ EKRAN     : Features/Offers/OldOffersView (@State private var viewModel) — Yük Veren'in "Eski teklifler"i; Features/Listings/HomeView sol üst saat ikonu açar
// │ SERVİS    : Features/Offers/OfferServicing → OfferService.shipperHistory / hide
// │ MODEL     : ShipperHistoryOffer | sohbet için ChatContext
// │ AKIŞ      : View .task → load() → shipperHistory → offers | Sil → hide() → load()
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: "Eski Teklifler" (Yük Veren, karara bağlanmış teklifler) ekranının durumu ve mantığı: liste, silme kuralı, sohbet
// BAĞLANTI: Features/Offers/OldOffersView.swift kullanır | servis: Features/Offers/OfferService.swift (OfferServicing sözleşmesi) | sohbet bilgisi: Features/Chat/ChatContext.swift
// ⮕ KULLANIM [OldOffersViewModel]: kullanır: OldOffersView › viewModel, OldOffersViewModelTests (test)
@Observable // @Observable [SWIFT]: sınıfı gözlemlenebilir yapar: değişkenleri değişince onları okuyan ekranlar kendiliğinden yenilenir
final class OldOffersViewModel {
    // ⮕ KULLANIM [service]: okur: OldOffersViewModel › load(), OldOffersViewModel › hide()
    private let service: OfferServicing

    // ⮕ ZİNCİR: Features/Offers/OldOffersView: List(viewModel.offers) | DOLDURAN: load() ← OfferService.shipperHistory | MODEL: [ShipperHistoryOffer]
    // ⮕ KULLANIM [offers]: YAZAR: OldOffersViewModel › load() | okur: OldOffersView › body, OldOffersViewModelTests (test)
    var offers: [ShipperHistoryOffer] = []
    // ⮕ ZİNCİR: Features/Offers/OldOffersView: if let errorMessage → kırmızı yazı
    // ⮕ KULLANIM [errorMessage]: YAZAR: OldOffersViewModel › load(), OldOffersViewModel › hide()
    var errorMessage: String?
    // ⮕ ZİNCİR: Features/Offers/OldOffersView: .navigationDestination(item: $viewModel.chat) { ChatView(context:) } | DOLDURAN: openChat(_:)
    // ⮕ KULLANIM [chat]: YAZAR: OldOffersViewModel › openChat() | bağlar(okur+yazar): OldOffersView › body
    var chat: ChatContext?

    init(service: OfferServicing = OfferService()) { self.service = service }

    // KURAL: yalnız reddedilen ya da tamamlanan silinebilir | kabul edilen AKTİF İŞ, silinemez (API de 409 verir)
    // ⮕ ZİNCİR: Features/Offers/OldOffersView: .swipeActions { if viewModel.canHide(offer) { "Sil" } } — yalnız reddedilen/tamamlanan (kabul edilen aktif iş, silinmez)
    // ⮕ KULLANIM [canHide]: çağırır: OldOffersView › body, OldOffersViewModelTests (test)
    func canHide(_ offer: ShipperHistoryOffer) -> Bool { ["Rejected", "Completed"].contains(offer.status) } // .contains [SWIFT]: içinde var mı diye bakar

    // ⮕ ZİNCİR: Features/Offers/OldOffersView: .task ve .refreshable | OfferService.shipperHistory()
    // ⮕ KULLANIM [load]: çağırır: OldOffersViewModel › hide(), OldOffersView › body, OldOffersViewModelTests (test)
    func load() async { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz)
        errorMessage = nil
        do { offers = try await service.shipperHistory() } // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
        catch { if let message = error.userMessage { errorMessage = message } }
    }

    // ⮕ ZİNCİR: Features/Offers/OldOffersView: Button("Sil") { Task { await viewModel.hide(offer) } } | OfferService.hide(offerId:) sonra load()
    // ⮕ KULLANIM [hide]: çağırır: OldOffersViewModel › hide(), OldOffersView › body, OldOffersViewModelTests (test)
    func hide(_ offer: ShipperHistoryOffer) async {
        errorMessage = nil
        do {
            try await service.hide(offerId: offer.id)
            await load()
        } catch {
            if let message = error.userMessage { errorMessage = message }
        }
    }

    // ⮕ ZİNCİR: Features/Offers/OldOffersView: Button("Sohbet") { viewModel.openChat(offer) } | chat = ChatContext.forShipperHistory(offer)
    // ⮕ KULLANIM [openChat]: çağırır: OldOffersView › body
    func openChat(_ offer: ShipperHistoryOffer) { chat = ChatContext.forShipperHistory(offer) }
}
