//
//  OfferListViewModels.swift
//  Yukum
//

import Foundation
import Observation

// Üç teklif listesi ekranının durum ve mantığı: Tekliflerim (Taşımacı), Gelen Teklifler (Yük Veren), Eski Teklifler (Yük Veren).
// Hepsi aynı kalıp: load (listeyi çek) → hide/decide (işlem yap, listeyi yenile) → hata yazısı. Kurallar (neyi silebilir, sohbette ne yapabilir) burada, testli.
// BAĞLANTI: View/MyOffersView.swift, ListingOffersView.swift, OldOffersView.swift | servis: Network/OfferService.swift (OfferServicing sözleşmesi)

// MARK: - Tekliflerim (Taşımacı)
@Observable
final class MyOffersViewModel {
    private let service: OfferServicing

    var offers: [CarrierOffer] = []
    var errorMessage: String?
    var chat: ChatContext? // dolunca ekran sohbeti açar (.navigationDestination(item:)), nil olunca kapanır | NEDEN değişken: List satırında NavigationLink düğmeleri bozar

    // İki bölüm: BEKLEYENLER (karar bekleyen) ve GEÇMİŞ (kabul/red/tamamlanan/iptal) | ana sayfada yalnız dokunulmamış ilanlar kalır, gerisi burada
    var pendingOffers: [CarrierOffer] { offers.filter { $0.status == "Pending" } }
    var historyOffers: [CarrierOffer] { offers.filter { $0.status != "Pending" } }

    init(service: OfferServicing = OfferService()) { self.service = service }

    // KURAL: yalnız BİTMİŞ teklif silinebilir (reddedilen, tamamlanan, iptal edilen) | bekleyen: karar yok | kabul edilen: AKTİF İŞ (API de 409 verir)
    func canHide(_ offer: CarrierOffer) -> Bool { ["Rejected", "Completed", "Cancelled"].contains(offer.status) }
    // KURAL: reddedilen teklifte sohbet yok | bekleyen, kabul, tamamlanan, iptalde düğme çıkar (kapalı olanlarda yalnız eski mesajlar okunur/silinir)
    func canChat(_ offer: CarrierOffer) -> Bool { offer.status != "Rejected" }

    func load() async {
        errorMessage = nil
        do { offers = try await service.myOffers() }
        catch { if let message = error.userMessage { errorMessage = message } }
    }

    // loadAndMarkSeen: ekran açılınca | ÖNCE listeyi çek ("Yeni" rozetleri çizilsin), SONRA "görüldü" yap (rozet söner)
    func loadAndMarkSeen() async {
        await load()
        try? await service.markSeen() // try?: hata olursa sessiz geç, kritik değil
    }

    func hide(_ offer: CarrierOffer) async {
        errorMessage = nil
        do {
            try await service.hide(offerId: offer.id)
            await load() // silindi, liste yenilenir
        } catch {
            if let message = error.userMessage { errorMessage = message } // örn. "Kabul edilmiş teklif aktif iştir; önce "İşi bitir" denmeli."
        }
    }

    func openChat(_ offer: CarrierOffer) { chat = ChatContext.forCarrier(offer) }
}

// MARK: - Gelen Teklifler (Yük Veren, bir ilanın bekleyen teklifleri)
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

// MARK: - Eski Teklifler (Yük Veren, karara bağlanmışlar)
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
