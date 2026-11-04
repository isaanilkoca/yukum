//
//  OfferService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 31.10.2026.
//

import Foundation // [SWIFT] ağ araçları

// ┌─ BAĞLANTI HARİTASI: OfferService (teklif uçları) ────────────────────────────────
// │ ÇAĞIRAN   : Features/Listings/ListingDetailViewModel (create) | ListingOffersViewModel (listingOffers, decide) | MyOffersViewModel (myOffers, markSeen, hide) | OldOffersViewModel (shipperHistory, hide) | HomeViewModel (unseenCount) — OfferServicing sözleşmesi üzerinden
// │ KULLANIR  : Core/Networking/APIClient | MODEL: CreateOfferRequest, OfferResponse, ListingOffer, CarrierOffer, ShipperHistoryOffer, UnseenCount
// │ API       : backend OffersController: /api/v1/listings/{id}/offers, /offers/{id}/accept|reject|complete, /offers/mine, /offers/history...
// │ SAHTESİ   : YukumTests/Support/FakeOfferService.swift
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA: teklif uçlarıyla konuşur. İsteğin kendisi (jeton, 401'de otomatik yenileme, hata çevirme) Core/Networking/APIClient.swift'te;
// burada yalnız "hangi adres, hangi paket, ne döner" yazılır.
// FONKSİYON HARİTASI (kim kullanır):
//   Taşımacı: create (teklif ver), myOffers (Tekliflerim), unseenCount (rozet), markSeen (rozeti söndür), hide (geçmişten sil)
//   Yük Veren: listingOffers (gelen bekleyen teklifler), decide (kabul/red), shipperHistory (eski teklifler), hide (geçmişten sil)
// BAĞLANTI: Features/Listings/ListingDetailView.swift, MyOffersView.swift, ListingOffersView.swift, OldOffersView.swift, HomeView.swift | kalıplar: Models/Offers/ | API: backend OffersController
// ⮕ KULLANIM [OfferService]: kullanır: HomeViewModel › init(), ListingDetailViewModel › init(), ListingOffersViewModel › init(), MyOffersViewModel › init(), OldOffersViewModel › init()
struct OfferService { // OfferService [BİZİM] ad

    // ⮕ KULLANIM [api]: okur: OfferService › create(), OfferService › listingOffers(), OfferService › decide(), OfferService › myOffers(), OfferService › unseenCount(), OfferService › markSeen() … +2
    private let api = APIClient.shared

    // create: teklif verir (aynı ilana tekrar verilirse eski teklifin tutarı güncellenir)
    // listingId: hangi ilan | _ body: tutar+not paketi | -> OfferResponse: kaydedilen teklif
    // ÇAĞIRAN: Features/Listings/ListingDetailView.swift "Teklifi Gönder" | API: POST /api/v1/listings/{id}/offers (yalnız Taşımacı)
    // ⮕ ZİNCİR: Features/Listings/ListingDetailViewModel.submit() ← Features/Listings/ListingDetailView "Teklifi Gönder" | API: POST /api/v1/listings/{id}/offers | GİDEN: CreateOfferRequest | DÖNEN: OfferResponse
    // ⮕ KULLANIM [create]: çağırır: ListingDetailViewModel › submit()
    func create(listingId: String, _ body: CreateOfferRequest) async throws -> OfferResponse { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
        try await api.send(.post, "/api/v1/listings/\(listingId)/offers", body: body, fallback: "Teklif gönderilemedi.") // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
    }

    // listingOffers: bir ilana gelen BEKLEYEN teklifleri getirir (karar verilenler geçmişe gider) | yalnız ilanın sahibi
    // ÇAĞIRAN: Features/Offers/ListingOffersView.swift | API: GET /api/v1/listings/{id}/offers
    // ⮕ ZİNCİR: Features/Offers/ListingOffersViewModel.load() ← Features/Offers/ListingOffersView .task/.refreshable | API: GET /api/v1/listings/{id}/offers | DÖNEN: [ListingOffer]
    // ⮕ KULLANIM [listingOffers]: çağırır: ListingOffersViewModel › load()
    func listingOffers(listingId: String) async throws -> [ListingOffer] {
        try await api.send(.get, "/api/v1/listings/\(listingId)/offers", fallback: "Teklifler alınamadı.")
    }

    // decide: teklifi kabul eder ya da reddeder | accept true → /accept, false → /reject | gövde yok, yalnız POST
    // ÇAĞIRAN: Features/Offers/ListingOffersView.swift Kabul Et / Reddet düğmeleri | API: POST /api/v1/offers/{id}/accept | reject
    // ⮕ ZİNCİR: Features/Offers/ListingOffersViewModel.decide() ← Features/Offers/ListingOffersView "Kabul et"/"Reddet" | API: POST /api/v1/offers/{id}/accept | reject | DÖNEN: yok
    // ⮕ KULLANIM [decide]: çağırır: ListingOffersViewModel › decide()
    func decide(offerId: String, accept: Bool) async throws {
        let action = accept ? "accept" : "reject" // ?: kısa if | adresin son parçası
        try await api.sendNoContent(.post, "/api/v1/offers/\(offerId)/\(action)", fallback: "İşlem yapılamadı.")
    }

    // myOffers: Taşımacı'nın verdiği TÜM teklifler (bekleyen + kabul + red + tamamlanan + iptal) | "Tekliflerim" ekranının verisi
    // ÇAĞIRAN: Features/Offers/MyOffersView.swift | API: GET /api/v1/offers/mine
    // ⮕ ZİNCİR: Features/Offers/MyOffersViewModel.load() ← Features/Offers/MyOffersView .task/.refreshable (ve silmeden sonra) | API: GET /api/v1/offers/mine | DÖNEN: [CarrierOffer]
    // ⮕ KULLANIM [myOffers]: çağırır: MyOffersViewModel › load()
    func myOffers() async throws -> [CarrierOffer] {
        try await api.send(.get, "/api/v1/offers/mine", fallback: "Teklifler alınamadı.")
    }

    // unseenCount: Taşımacı'nın henüz GÖRMEDİĞİ karar sayısı | NE İŞE YARAR: push bildirim yerine uygulama içi kırmızı rozet
    // ÇAĞIRAN: Features/Listings/HomeView.swift (Taşımacı) | API: GET /api/v1/offers/mine/unseen-count → {"count": 3}
    // ⮕ ZİNCİR: Features/Listings/HomeViewModel.load() (Taşımacı) → Features/Listings/HomeView kutu ikonu rozeti | API: GET /api/v1/offers/mine/unseen-count | DÖNEN: Int (UnseenCount.count)
    // ⮕ KULLANIM [unseenCount]: çağırır: HomeViewModel › load()
    func unseenCount() async throws -> Int { // -> Int: yalnız sayı döner
        let result: UnseenCount = try await api.send(.get, "/api/v1/offers/mine/unseen-count", fallback: "Bildirim sayısı alınamadı.")
        return result.count // struct'tan yalnız sayıyı al
    }

    // markSeen: karar bildirimlerini "görüldü" yapar (rozet söner) | sunucuda Offer.CarrierSeen=true olur
    // ÇAĞIRAN: Features/Offers/MyOffersView.swift → .task, liste çizildikten SONRA | API: POST /api/v1/offers/mine/seen
    // ⮕ ZİNCİR: Features/Offers/MyOffersViewModel.loadAndMarkSeen() ← Features/Offers/MyOffersView .task (liste çizildikten SONRA) | API: POST /api/v1/offers/mine/seen | DÖNEN: yok
    // ⮕ KULLANIM [markSeen]: çağırır: MyOffersViewModel › loadAndMarkSeen()
    func markSeen() async throws {
        try await api.sendNoContent(.post, "/api/v1/offers/mine/seen", fallback: "İşlem yapılamadı.")
    }

    // hide: teklifi KENDİ geçmişimden siler; karşı taraf görmeye devam eder (kayıt DB'den silinmez, bayrak işaretlenir) | yalnız bitmiş teklifler (reddedilen/tamamlanan/iptal) silinebilir
    // ÇAĞIRAN: MyOffersView ve OldOffersView, satırı kaydırıp "Sil" | API: DELETE /api/v1/offers/{id}
    // ⮕ ZİNCİR: Features/Offers/MyOffersViewModel.hide() ve OldOffersViewModel.hide() ← satırı kaydırıp "Sil" (MyOffersView, OldOffersView) | API: DELETE /api/v1/offers/{id} | DÖNEN: yok
    // ⮕ KULLANIM [hide]: çağırır: MyOffersViewModel › hide(), OldOffersViewModel › hide()
    func hide(offerId: String) async throws {
        try await api.sendNoContent(.delete, "/api/v1/offers/\(offerId)", fallback: "Silinemedi.")
    }

    // shipperHistory: Yük Veren'in karara bağladığı (kabul/red/tamamlanan) teklifler = "Eski teklifler"
    // ÇAĞIRAN: Features/Offers/OldOffersView.swift | API: GET /api/v1/offers/history
    // ⮕ ZİNCİR: Features/Offers/OldOffersViewModel.load() ← Features/Offers/OldOffersView .task/.refreshable | API: GET /api/v1/offers/history | DÖNEN: [ShipperHistoryOffer]
    // ⮕ KULLANIM [shipperHistory]: çağırır: OldOffersViewModel › load()
    func shipperHistory() async throws -> [ShipperHistoryOffer] {
        try await api.send(.get, "/api/v1/offers/history", fallback: "Eski teklifler alınamadı.")
    }
}

// OfferService, kendi sözleşmesini karşılar (Services/Protocols/): ViewModel'ler somut sınıfa değil sözleşmeye bağlıdır, testte sahtesi verilir
extension OfferService: OfferServicing {} // extension [SWIFT]: mevcut türe sonradan özellik/uyum ekler
