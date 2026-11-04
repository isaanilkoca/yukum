//
//  OfferService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 31.10.2026.
//

import Foundation // [SWIFT] ağ araçları

// BU DOSYA: teklif uçlarıyla konuşur. İsteğin kendisi (jeton, 401'de otomatik yenileme, hata çevirme) Networking/APIClient.swift'te;
// burada yalnız "hangi adres, hangi paket, ne döner" yazılır.
// FONKSİYON HARİTASI (kim kullanır):
//   Taşımacı: create (teklif ver), myOffers (Tekliflerim), unseenCount (rozet), markSeen (rozeti söndür), hide (geçmişten sil)
//   Yük Veren: listingOffers (gelen bekleyen teklifler), decide (kabul/red), shipperHistory (eski teklifler), hide (geçmişten sil)
// BAĞLANTI: Views/ListingDetailView.swift, MyOffersView.swift, ListingOffersView.swift, OldOffersView.swift, HomeView.swift | kalıplar: Models/Offers/ | API: backend OffersController
struct OfferService { // OfferService [BİZİM] ad

    private let api = APIClient.shared

    // create: teklif verir (aynı ilana tekrar verilirse eski teklifin tutarı güncellenir)
    // listingId: hangi ilan | _ body: tutar+not paketi | -> OfferResponse: kaydedilen teklif
    // ÇAĞIRAN: Views/ListingDetailView.swift "Teklifi Gönder" | API: POST /api/v1/listings/{id}/offers (yalnız Taşımacı)
    func create(listingId: String, _ body: CreateOfferRequest) async throws -> OfferResponse {
        try await api.send(.post, "/api/v1/listings/\(listingId)/offers", body: body, fallback: "Teklif gönderilemedi.")
    }

    // listingOffers: bir ilana gelen BEKLEYEN teklifleri getirir (karar verilenler geçmişe gider) | yalnız ilanın sahibi
    // ÇAĞIRAN: Views/ListingOffersView.swift | API: GET /api/v1/listings/{id}/offers
    func listingOffers(listingId: String) async throws -> [ListingOffer] {
        try await api.send(.get, "/api/v1/listings/\(listingId)/offers", fallback: "Teklifler alınamadı.")
    }

    // decide: teklifi kabul eder ya da reddeder | accept true → /accept, false → /reject | gövde yok, yalnız POST
    // ÇAĞIRAN: Views/ListingOffersView.swift Kabul Et / Reddet düğmeleri | API: POST /api/v1/offers/{id}/accept | reject
    func decide(offerId: String, accept: Bool) async throws {
        let action = accept ? "accept" : "reject" // ?: kısa if | adresin son parçası
        try await api.sendNoContent(.post, "/api/v1/offers/\(offerId)/\(action)", fallback: "İşlem yapılamadı.")
    }

    // myOffers: Taşımacı'nın verdiği TÜM teklifler (bekleyen + kabul + red + tamamlanan + iptal) | "Tekliflerim" ekranının verisi
    // ÇAĞIRAN: Views/MyOffersView.swift | API: GET /api/v1/offers/mine
    func myOffers() async throws -> [CarrierOffer] {
        try await api.send(.get, "/api/v1/offers/mine", fallback: "Teklifler alınamadı.")
    }

    // unseenCount: Taşımacı'nın henüz GÖRMEDİĞİ karar sayısı | NE İŞE YARAR: push bildirim yerine uygulama içi kırmızı rozet
    // ÇAĞIRAN: Views/HomeView.swift (Taşımacı) | API: GET /api/v1/offers/mine/unseen-count → {"count": 3}
    func unseenCount() async throws -> Int { // -> Int: yalnız sayı döner
        let result: UnseenCount = try await api.send(.get, "/api/v1/offers/mine/unseen-count", fallback: "Bildirim sayısı alınamadı.")
        return result.count // struct'tan yalnız sayıyı al
    }

    // markSeen: karar bildirimlerini "görüldü" yapar (rozet söner) | sunucuda Offer.CarrierSeen=true olur
    // ÇAĞIRAN: Views/MyOffersView.swift → .task, liste çizildikten SONRA | API: POST /api/v1/offers/mine/seen
    func markSeen() async throws {
        try await api.sendNoContent(.post, "/api/v1/offers/mine/seen", fallback: "İşlem yapılamadı.")
    }

    // hide: teklifi KENDİ geçmişimden siler; karşı taraf görmeye devam eder (kayıt DB'den silinmez, bayrak işaretlenir) | yalnız bitmiş teklifler (reddedilen/tamamlanan/iptal) silinebilir
    // ÇAĞIRAN: MyOffersView ve OldOffersView, satırı kaydırıp "Sil" | API: DELETE /api/v1/offers/{id}
    func hide(offerId: String) async throws {
        try await api.sendNoContent(.delete, "/api/v1/offers/\(offerId)", fallback: "Silinemedi.")
    }

    // shipperHistory: Yük Veren'in karara bağladığı (kabul/red/tamamlanan) teklifler = "Eski teklifler"
    // ÇAĞIRAN: Views/OldOffersView.swift | API: GET /api/v1/offers/history
    func shipperHistory() async throws -> [ShipperHistoryOffer] {
        try await api.send(.get, "/api/v1/offers/history", fallback: "Eski teklifler alınamadı.")
    }
}

// OfferService, kendi sözleşmesini karşılar (Services/Protocols/): ViewModel'ler somut sınıfa değil sözleşmeye bağlıdır, testte sahtesi verilir
extension OfferService: OfferServicing {}
