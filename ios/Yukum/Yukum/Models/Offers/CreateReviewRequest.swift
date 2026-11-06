//
//  CreateReviewRequest.swift
//  Yukum
//

import Foundation

// Puan gönderirken API'ye giden paket | Encodable [SWIFT]: Swift değerini JSON'a çevirir | alan adları API ile birebir aynı
// BAĞLANTI: RatingViewModel hazırlar → ReviewService.create → POST /api/v1/offers/{id}/review
struct CreateReviewRequest: Encodable {
    let rating: Int // 1–5
    let comment: String? // isteğe bağlı yorum | nil ise JSON'a yazılmaz
}
