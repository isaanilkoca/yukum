//
//  OfferServicing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: OfferServicing (sözleşme) ───────────────────────────────────
// │ GERÇEK    : Models/Services/OfferService.swift | SAHTE (test): YukumTests/Support/FakeOfferService.swift
// │ KULLANAN  : ViewModels/HomeViewModel (unseenCount), MyOffersViewModel, ListingOffersViewModel, OldOffersViewModel, ListingDetailViewModel
// └──────────────────────────────────────────────────────────────────────

// ⮕ KULLANIM [OfferServicing]: kullanır: HomeViewModel › offerService, HomeViewModel › init(), ListingDetailViewModel › service, ListingDetailViewModel › init(), ListingOffersViewModel › offerService, ListingOffersViewModel › init() … +6
protocol OfferServicing { // protocol [SWIFT]: sözleşme: "bu fonksiyonlara sahip olan her şey bu sözleşmeyi karşılar"
    // ⮕ KULLANIM [create]: çağırır: ListingDetailViewModel › submit()
    func create(listingId: String, _ body: CreateOfferRequest) async throws -> OfferResponse // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
    // ⮕ KULLANIM [listingOffers]: çağırır: ListingOffersViewModel › load()
    func listingOffers(listingId: String) async throws -> [ListingOffer]
    // ⮕ KULLANIM [decide]: çağırır: ListingOffersViewModel › decide()
    func decide(offerId: String, accept: Bool) async throws
    // ⮕ KULLANIM [myOffers]: çağırır: MyOffersViewModel › load()
    func myOffers() async throws -> [CarrierOffer]
    // ⮕ KULLANIM [unseenCount]: çağırır: HomeViewModel › load()
    func unseenCount() async throws -> Int
    // ⮕ KULLANIM [markSeen]: çağırır: MyOffersViewModel › loadAndMarkSeen()
    func markSeen() async throws
    // ⮕ KULLANIM [hide]: çağırır: MyOffersViewModel › hide(), OldOffersViewModel › hide()
    func hide(offerId: String) async throws
    
    // withdraw: Taşımacı BEKLEYEN teklifini geri çeker | ÇAĞIRAN: MyOffersViewModel.withdraw() | UYGULAYAN: OfferService | SAHTESİ: YukumTests/Support/FakeOfferService
    // protocol'de gövde yazılmaz, yalnız imza vardır: "bu fonksiyon olmalı" | async throws [SWIFT]: beklemeli iş + hata fırlatabilir
    func withdraw(offerId: String) async throws
    // advance: Taşımacı kabul edilmiş işi bir sonraki aşamaya geçirir (yük alındı → yolda → teslim edildi) | ÇAĞIRAN: MyOffersViewModel.advance() | API: POST /api/v1/offers/{id}/advance
    func advance(offerId: String) async throws
    
    // ⮕ KULLANIM [shipperHistory]: çağırır: OldOffersViewModel › load()
    func shipperHistory() async throws -> [ShipperHistoryOffer]
}
