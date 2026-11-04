//
//  MyOffersViewModel.swift
//  Yukum
//

import Foundation
import Observation

// BU SINIF: "Tekliflerim" (Taşımacı) ekranının durumu ve mantığı: teklif listesi, Bekleyenler/Geçmiş bölümleri, silme ve sohbet kuralları, "görüldü" işaretleme
// BAĞLANTI: View/MyOffersView.swift kullanır | servis: Network/OfferService.swift (OfferServicing sözleşmesi) | sohbet bilgisi: ViewModel/ChatContext.swift
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
