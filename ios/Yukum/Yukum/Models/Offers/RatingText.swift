//
//  RatingText.swift
//  Yukum
//

import Foundation

// Puanı ekranda tek biçimde yazar | enum + static [SWIFT]: örnek üretilmeyen yardımcı kalıp (yalnız fonksiyon taşır)
// BAĞLANTI: Views/ListingOffersView (teklif satırı), Views/CarrierProfileView (başlık)
enum RatingText {
    // summary: "★ 4.5 (8)" | hiç puan yoksa "Yeni" | String(format:) [SWIFT, Foundation]: ondalığı sabit basamakla yazar (%.1f = 1 basamak)
    static func summary(rating: Double, count: Int) -> String {
        count == 0 ? "Yeni" : "★ " + String(format: "%.1f", rating) + " (\(count))"
    }
}
