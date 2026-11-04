//
//  OldOffersViewModel.swift
//  Yukum
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: OldOffersViewModel ──────────────────────────────────────────
// │ EKRAN     : Views/OldOffersView (@State private var viewModel) — Yük Veren'in "Eski teklifler"i; Views/HomeView sol üst saat ikonu açar
// │ SERVİS    : Services/Protocols/OfferServicing → OfferService.shipperHistory / hide
// │ MODEL     : ShipperHistoryOffer | sohbet için ChatContext
// │ AKIŞ      : View .task → load() → shipperHistory → offers | Sil → hide() → load()
// │ HAZIR (Swift/Apple) [SWIFT] : @Observable, async, await, String, Bool, Observation, .contains
// │ BİZİM (bizim yazdığımız) [BİZİM] : türler: OldOffersViewModel | fonksiyonlar: canHide, load, hide, openChat | değişken/durumlar: service, offers, errorMessage, chat, message
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: "Eski Teklifler" (Yük Veren, karara bağlanmış teklifler) ekranının durumu ve mantığı: liste, silme kuralı, sohbet
// BAĞLANTI: Views/OldOffersView.swift kullanır | servis: Services/OfferService.swift (OfferServicing sözleşmesi) | sohbet bilgisi: ViewModels/ChatContext.swift
@Observable // @Observable [SWIFT]: sınıfı gözlemlenebilir yapar: değişkenleri değişince onları okuyan ekranlar kendiliğinden yenilenir
final class OldOffersViewModel {
    private let service: OfferServicing

    // ⮕ ZİNCİR: Views/OldOffersView: List(viewModel.offers) | DOLDURAN: load() ← OfferService.shipperHistory | MODEL: [ShipperHistoryOffer]
    var offers: [ShipperHistoryOffer] = []
    // ⮕ ZİNCİR: Views/OldOffersView: if let errorMessage → kırmızı yazı
    var errorMessage: String?
    // ⮕ ZİNCİR: Views/OldOffersView: .navigationDestination(item: $viewModel.chat) { ChatView(context:) } | DOLDURAN: openChat(_:)
    var chat: ChatContext?

    init(service: OfferServicing = OfferService()) { self.service = service }

    // KURAL: yalnız reddedilen ya da tamamlanan silinebilir | kabul edilen AKTİF İŞ, silinemez (API de 409 verir)
    // ⮕ ZİNCİR: Views/OldOffersView: .swipeActions { if viewModel.canHide(offer) { "Sil" } } — yalnız reddedilen/tamamlanan (kabul edilen aktif iş, silinmez)
    func canHide(_ offer: ShipperHistoryOffer) -> Bool { ["Rejected", "Completed"].contains(offer.status) } // .contains [SWIFT]: içinde var mı diye bakar

    // ⮕ ZİNCİR: Views/OldOffersView: .task ve .refreshable | OfferService.shipperHistory()
    func load() async { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz)
        errorMessage = nil
        do { offers = try await service.shipperHistory() } // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
        catch { if let message = error.userMessage { errorMessage = message } }
    }

    // ⮕ ZİNCİR: Views/OldOffersView: Button("Sil") { Task { await viewModel.hide(offer) } } | OfferService.hide(offerId:) sonra load()
    func hide(_ offer: ShipperHistoryOffer) async {
        errorMessage = nil
        do {
            try await service.hide(offerId: offer.id)
            await load()
        } catch {
            if let message = error.userMessage { errorMessage = message }
        }
    }

    // ⮕ ZİNCİR: Views/OldOffersView: Button("Sohbet") { viewModel.openChat(offer) } | chat = ChatContext.forShipperHistory(offer)
    func openChat(_ offer: ShipperHistoryOffer) { chat = ChatContext.forShipperHistory(offer) }
}
