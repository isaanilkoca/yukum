//
//  ReviewService.swift
//  Yukum
//

import Foundation

// Puan ve Taşımacı profili uçlarıyla konuşur | jeton, 401'de yenileme, hata çevirme APIClient'ta; burada yalnız "hangi adres, ne gider, ne döner"
// ÇAĞIRAN: CarrierProfileViewModel (carrierProfile), RatingViewModel (create) | API: backend ReviewsController
struct ReviewService {
    private let api = APIClient.shared // tüm istekler bu kapıdan geçer

    // create: 201 cevabın gövdesini kullanmayız (sendNoContent) | 409 "zaten puan verdin" gibi hatalar APIError olur, mesaj Türkçe gelir
    func create(offerId: String, _ body: CreateReviewRequest) async throws {
        try await api.sendNoContent(.post, "/api/v1/offers/\(offerId)/review", body: body, fallback: "Puan gönderilemedi.")
    }

    // carrierProfile: send<Response>: JSON'u dönüş türüne (CarrierProfile) çevirir
    func carrierProfile(id: String) async throws -> CarrierProfile {
        try await api.send(.get, "/api/v1/carriers/\(id)", fallback: "Profil yüklenemedi.")
    }

    // shipperProfile (15 Kasım, 8. adım): GET /api/v1/shippers/{id} → ReviewsController.ShipperProfile → GetShipperProfileHandler
    func shipperProfile(id: String) async throws -> ShipperPublicProfile {
        try await api.send(.get, "/api/v1/shippers/\(id)", fallback: "Profil yüklenemedi.")
    }
}

extension ReviewService: ReviewServicing {} // extension [SWIFT]: mevcut türe sonradan uyum ekler
