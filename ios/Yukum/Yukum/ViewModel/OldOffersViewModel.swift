//
//  OldOffersViewModel.swift
//  Yukum
//

import Foundation
import Observation

// BU SINIF: "Eski Teklifler" (Yük Veren, karara bağlanmış teklifler) ekranının durumu ve mantığı: liste, silme kuralı, sohbet
// BAĞLANTI: View/OldOffersView.swift kullanır | servis: Network/OfferService.swift (OfferServicing sözleşmesi) | sohbet bilgisi: ViewModel/ChatContext.swift
@Observable
final class OldOffersViewModel {
    private let service: OfferServicing

    var offers: [ShipperHistoryOffer] = []
    var errorMessage: String?
    var chat: ChatContext?

    init(service: OfferServicing = OfferService()) { self.service = service }

    // KURAL: yalnız reddedilen ya da tamamlanan silinebilir | kabul edilen AKTİF İŞ, silinemez (API de 409 verir)
    func canHide(_ offer: ShipperHistoryOffer) -> Bool { ["Rejected", "Completed"].contains(offer.status) }

    func load() async {
        errorMessage = nil
        do { offers = try await service.shipperHistory() }
        catch { if let message = error.userMessage { errorMessage = message } }
    }

    func hide(_ offer: ShipperHistoryOffer) async {
        errorMessage = nil
        do {
            try await service.hide(offerId: offer.id)
            await load()
        } catch {
            if let message = error.userMessage { errorMessage = message }
        }
    }

    func openChat(_ offer: ShipperHistoryOffer) { chat = ChatContext.forShipperHistory(offer) }
}
