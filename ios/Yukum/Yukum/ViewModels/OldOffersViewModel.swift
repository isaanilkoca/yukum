//
//  OldOffersViewModel.swift
//  Yukum
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: OldOffersViewModel ──────────────────────────────────────────
// │ EKRAN     : Views/OldOffersView (@State private var viewModel) — Yük Veren'in "Eski teklifler"i; Views/HomeView sol üst saat ikonu açar
// │ SERVİS    : Models/Services/Protocols/OfferServicing → OfferService.shipperHistory / hide
// │ MODEL     : ShipperHistoryOffer | sohbet için ChatContext
// │ AKIŞ      : View .task → load() → shipperHistory → offers | Sil → hide() → load()
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: "Eski Teklifler" (Yük Veren, karara bağlanmış teklifler) ekranının durumu ve mantığı: liste, silme kuralı, sohbet
// BAĞLANTI: Views/OldOffersView.swift kullanır | servis: Models/Services/OfferService.swift (OfferServicing sözleşmesi) | sohbet bilgisi: ViewModels/ChatContext.swift
// ⮕ KULLANIM [OldOffersViewModel]: kullanır: OldOffersView › viewModel, OldOffersViewModelTests (test)
@Observable // @Observable [SWIFT]: sınıfı gözlemlenebilir yapar: değişkenleri değişince onları okuyan ekranlar kendiliğinden yenilenir
final class OldOffersViewModel {
    // ⮕ KULLANIM [service]: okur: OldOffersViewModel › load(), OldOffersViewModel › hide()
    private let service: OfferServicing

    // ⮕ ZİNCİR: Views/OldOffersView: List(viewModel.offers) | DOLDURAN: load() ← OfferService.shipperHistory | MODEL: [ShipperHistoryOffer]
    // ⮕ KULLANIM [offers]: YAZAR: OldOffersViewModel › load() | okur: OldOffersView › body, OldOffersViewModelTests (test)
    var offers: [ShipperHistoryOffer] = []
    // ⮕ ZİNCİR: Views/OldOffersView: if let errorMessage → kırmızı yazı
    // ⮕ KULLANIM [errorMessage]: YAZAR: OldOffersViewModel › load(), OldOffersViewModel › hide()
    var errorMessage: String?
    // ⮕ ZİNCİR: Views/OldOffersView: .navigationDestination(item: $viewModel.chat) { ChatView(context:) } | DOLDURAN: openChat(_:)
    // ⮕ KULLANIM [chat]: YAZAR: OldOffersViewModel › openChat() | bağlar(okur+yazar): OldOffersView › body
    var chat: ChatContext?
    var profileCarrierId: String? // dolunca CarrierProfileView açılır (chat ile aynı kalıp)
    var ratingOffer: ShipperHistoryOffer? // dolunca RatingView sayfası alttan açılır (.sheet(item:))

    init(service: OfferServicing = OfferService()) { self.service = service }

    // KURAL: yalnız reddedilen ya da tamamlanan silinebilir | kabul edilen AKTİF İŞ, silinemez (API de 409 verir)
    // ⮕ ZİNCİR: Views/OldOffersView: .swipeActions { if viewModel.canHide(offer) { "Sil" } } — yalnız reddedilen/tamamlanan (kabul edilen aktif iş, silinmez)
    // ⮕ KULLANIM [canHide]: çağırır: OldOffersView › body, OldOffersViewModelTests (test)
    func canHide(_ offer: ShipperHistoryOffer) -> Bool { ["Rejected", "Completed", "Cancelled"].contains(offer.status) } // 15 Kasım: karşılıklı iptal edilen de silinebilir // .contains [SWIFT]: içinde var mı diye bakar

    // ⮕ ZİNCİR: Views/OldOffersView: .task ve .refreshable | OfferService.shipperHistory()
    // ⮕ KULLANIM [load]: çağırır: OldOffersViewModel › hide(), OldOffersView › body, OldOffersViewModelTests (test)
    func load() async { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz)
        errorMessage = nil
        do { offers = try await service.shipperHistory() } // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
        catch { if let message = error.userMessage { errorMessage = message } }
    }

    // ⮕ ZİNCİR: Views/OldOffersView: Button("Sil") { Task { await viewModel.hide(offer) } } | OfferService.hide(offerId:) sonra load()
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

    // ─── KARŞILIKLI İPTAL (15 Kasım) ─── kurallar sunucuda (backend CancelRequestHandlers); burada yalnız ne zaman düğme çıkacağı
    // canRequestCancel: kabul edilmiş, teslim edilmemiş ve açık talebi olmayan iş
    func canRequestCancel(_ offer: ShipperHistoryOffer) -> Bool {
        offer.status == "Accepted" && offer.stage != "Delivered" && offer.cancelRequest == nil
    }
    // Her işlem aynı kalıp: servise söyle → başarılıysa listeyi yenile → hata varsa Türkçe mesaj | -> Bool: ekran animasyonu yalnız başarıda oynatsın
    func requestCancel(_ offer: ShipperHistoryOffer, reason: String, note: String?, reopenListing: Bool) async -> Bool {
        await run { try await self.service.requestCancel(offerId: offer.id, reason: reason, note: note, reopenListing: reopenListing) }
    }
    func approveCancel(_ offer: ShipperHistoryOffer, reopenListing: Bool) async -> Bool {
        await run { try await self.service.approveCancel(offerId: offer.id, reopenListing: reopenListing) }
    }
    func rejectCancel(_ offer: ShipperHistoryOffer) async -> Bool { await run { try await self.service.rejectCancel(offerId: offer.id) } }
    func withdrawCancel(_ offer: ShipperHistoryOffer) async -> Bool { await run { try await self.service.withdrawCancel(offerId: offer.id) } }

    private func run(_ work: @escaping () async throws -> Void) async -> Bool {
        errorMessage = nil
        do { try await work(); await load(); return true }
        catch { if let message = error.userMessage { errorMessage = message }; return false }
    }

    // ⮕ ZİNCİR: Views/OldOffersView: Button("Sohbet") { viewModel.openChat(offer) } | chat = ChatContext.forShipperHistory(offer)
    // ⮕ KULLANIM [openChat]: çağırır: OldOffersView › body
    func openChat(_ offer: ShipperHistoryOffer) { chat = ChatContext.forShipperHistory(offer) }

    // stageTitle: Yük Veren'in izlediği aşama yazısı (Taşımacı ilerletir) | JobStage'e çevrilemezse boş
    // ZİNCİR: Views/OldOffersView "Kabul ettin · Yolda" ← API stage alanı (GET /offers/history)
    func stageTitle(_ offer: ShipperHistoryOffer) -> String { (JobStage(rawValue: offer.stage) ?? .notStarted).title }

    // KURAL: yalnız TAMAMLANMIŞ ve henüz PUANLANMAMIŞ iş puanlanır | sunucu da denetler (409)
    // ZİNCİR: Views/OldOffersView: if viewModel.canRate(offer) { "Puan ver" } → ratingOffer dolar → RatingView
    func canRate(_ offer: ShipperHistoryOffer) -> Bool { offer.status == "Completed" && !offer.reviewed }
}
