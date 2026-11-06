//
//  RatingViewModel.swift
//  Yukum
//

import Foundation
import Observation

// ┌─ BAĞLANTI HARİTASI: RatingViewModel ─────────────────────────────────────────────
// │ EKRAN     : Views/RatingView (alttan açılan sayfa) | açan: OldOffersView ("Puan ver") ve ChatView (işi bitirince)
// │ SERVİS    : ReviewServicing → ReviewService | API: POST /api/v1/offers/{offerId}/review | GİDEN: CreateReviewRequest
// └──────────────────────────────────────────────────────────────────────

@Observable
final class RatingViewModel {
    let offerId: String // hangi işi puanlıyoruz
    let carrierName: String // ekranda "… için puan ver" yazısı
    private let service: ReviewServicing

    var rating = 5 // seçili yıldız sayısı (1–5) | varsayılan 5: tek dokunuşla gönderilebilsin
    var comment = "" // isteğe bağlı yorum | TextField String ile çalışır
    var errorMessage: String? // örn. 409 "Bu iş için zaten puan verdin."
    var isSending = false // true iken düğme kilitlenir (çift gönderim olmasın)

    static let maxComment = 500 // sunucu sınırı ile aynı

    init(offerId: String, carrierName: String, service: ReviewServicing = ReviewService()) {
        self.offerId = offerId
        self.carrierName = carrierName
        self.service = service
    }

    // submit: puanı gönderir | -> Bool: başarılı mı (View başarıda sayfayı kapatır)
    // ZİNCİR: RatingView "Gönder" → bu fonksiyon → ReviewService.create → POST /api/v1/offers/{id}/review
    // Sunucu hatasının Türkçe mesajı errorMessage'a yazılır | guard [SWIFT]: şart sağlanmazsa erken çık
    func submit() async -> Bool {
        guard (1...5).contains(rating) else { errorMessage = "Puan 1 ile 5 arasında olmalı."; return false } // 1...5 [SWIFT]: kapalı aralık
        guard comment.count <= Self.maxComment else { errorMessage = "Yorum en fazla 500 karakter olabilir."; return false }
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await service.create(offerId: offerId, CreateReviewRequest(rating: rating, comment: trimmed.isEmpty ? nil : trimmed))
            return true
        } catch {
            if let message = error.userMessage { errorMessage = message }
            return false
        }
    }
}
