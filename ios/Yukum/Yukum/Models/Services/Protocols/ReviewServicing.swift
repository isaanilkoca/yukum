//
//  ReviewServicing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: ReviewServicing (sözleşme) ──────────────────────────────────
// │ GERÇEK    : Models/Services/ReviewService.swift | SAHTE (test): YukumTests/Support/FakeReviewService.swift
// │ KULLANAN  : ViewModels/CarrierProfileViewModel (profil), ViewModels/RatingViewModel (puan ver)
// └──────────────────────────────────────────────────────────────────────

protocol ReviewServicing { // protocol [SWIFT]: sözleşme: "bu fonksiyonlara sahip olan her şey bu sözleşmeyi karşılar"
    // create: Yük Veren tamamlanmış işi puanlar | API: POST /api/v1/offers/{offerId}/review
    func create(offerId: String, _ body: CreateReviewRequest) async throws
    // carrierProfile: Taşımacı profili (ortalama, yorumlar) | API: GET /api/v1/carriers/{id}
    func carrierProfile(id: String) async throws -> CarrierProfile
    func shipperProfile(id: String) async throws -> ShipperPublicProfile // 15 Kasım: Yük Veren profili (ShipperProfileView)
}
