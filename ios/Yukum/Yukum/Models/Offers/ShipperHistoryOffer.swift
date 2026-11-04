//
//  ShipperHistoryOffer.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: ShipperHistoryOffer (Yük Veren'in karara bağladığı teklif) ───
// │ MODEL     : Yük Veren'in kabul/red verdiği ya da tamamlanan tek teklif ("Eski teklifler")
// │ ÜRETEN    : Services/OfferService.shipperHistory ← GET /api/v1/offers/history
// │ SAKLAYAN  : ViewModels/OldOffersViewModel.offers → Views/OldOffersView
// │ SOHBET    : ViewModels/ChatContext.forShipperHistory(_:)
// └──────────────────────────────────────────────────────────────────────

// ShipperHistoryOffer: Yük Veren'in "Eski teklifler" listesindeki TEK SATIRIN kalıbı (karara bağladığı bir teklif).
// NE İŞE YARAR: GET /api/v1/offers/history'deki her eleman bu struct'a çevrilir | alan adları API ile BİREBİR aynı olmalı
// NEREDE KULLANILIR: Services/OfferService.swift → shipperHistory() bu struct'ın listesini döner → Views/OldOffersView.swift listeyi çizer
struct ShipperHistoryOffer: Decodable, Identifiable { // Decodable [SWIFT]: JSON'dan üretilir | Identifiable [SWIFT]: benzersiz id'si var
    let id: String // teklif numarası | silme isteğine (hide) bu gider
    let listingTitle: String // hangi ilana gelen teklif | satırın üst yazısı
    let fromCityName: String // kalkış ili
    let fromDistrictName: String // kalkış ilçesi
    let toCityName: String // varış ili
    let toDistrictName: String // varış ilçesi
    let weightKg: Int // yükün ağırlığı (kg)
    let pickupDate: String // yükleme tarihi "2026-11-05" yazısı
    let carrierName: String // teklifi veren Taşımacı'nın adı | NE İŞE YARAR: kime kabul/red verdiğimi hatırlamak
    let amount: Double // teklif tutarı (API 48000.0 gönderir)
    let status: String // "Accepted" (kabul ettim) / "Rejected" (reddettim) | geçmişte "Pending" olmaz, yalnız karar verilmişler gelir
}
