//
//  ShipperHistoryOffer.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: ShipperHistoryOffer (Yük Veren'in karara bağladığı teklif) ───
// │ MODEL     : Yük Veren'in kabul/red verdiği ya da tamamlanan tek teklif ("Eski teklifler")
// │ ÜRETEN    : Features/Offers/OfferService.shipperHistory ← GET /api/v1/offers/history
// │ SAKLAYAN  : Features/Offers/OldOffersViewModel.offers → Features/Offers/OldOffersView
// │ SOHBET    : Features/Chat/ChatContext.forShipperHistory(_:)
// └──────────────────────────────────────────────────────────────────────

// ShipperHistoryOffer: Yük Veren'in "Eski teklifler" listesindeki TEK SATIRIN kalıbı (karara bağladığı bir teklif).
// NE İŞE YARAR: GET /api/v1/offers/history'deki her eleman bu struct'a çevrilir | alan adları API ile BİREBİR aynı olmalı
// NEREDE KULLANILIR: Features/Offers/OfferService.swift → shipperHistory() bu struct'ın listesini döner → Features/Offers/OldOffersView.swift listeyi çizer
// ⮕ KULLANIM [ShipperHistoryOffer]: kullanır: ChatContext › forShipperHistory(), OldOffersViewModel › offers, OldOffersViewModel › canHide(), OldOffersViewModel › hide(), OldOffersViewModel › openChat(), OfferService › shipperHistory() … +3
struct ShipperHistoryOffer: Decodable, Identifiable { // Decodable [SWIFT]: JSON'dan üretilir | Identifiable [SWIFT]: benzersiz id'si var
    // ⮕ KULLANIM [id]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let id: String // teklif numarası | silme isteğine (hide) bu gider
    // ⮕ KULLANIM [listingTitle]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let listingTitle: String // hangi ilana gelen teklif | satırın üst yazısı
    // ⮕ KULLANIM [fromCityName]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let fromCityName: String // kalkış ili
    // ⮕ KULLANIM [fromDistrictName]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let fromDistrictName: String // kalkış ilçesi
    // ⮕ KULLANIM [toCityName]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let toCityName: String // varış ili
    // ⮕ KULLANIM [toDistrictName]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let toDistrictName: String // varış ilçesi
    // ⮕ KULLANIM [weightKg]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let weightKg: Int // yükün ağırlığı (kg)
    // ⮕ KULLANIM [pickupDate]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let pickupDate: String // yükleme tarihi "2026-11-05" yazısı
    // ⮕ KULLANIM [carrierName]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let carrierName: String // teklifi veren Taşımacı'nın adı | NE İŞE YARAR: kime kabul/red verdiğimi hatırlamak
    // ⮕ KULLANIM [amount]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let amount: Double // teklif tutarı (API 48000.0 gönderir)
    // ⮕ KULLANIM [status]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let status: String // "Accepted" (kabul ettim) / "Rejected" (reddettim) | geçmişte "Pending" olmaz, yalnız karar verilmişler gelir
}
