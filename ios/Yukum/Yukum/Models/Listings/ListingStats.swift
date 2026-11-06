//
//  ListingStats.swift
//  Yukum
//

import Foundation

// İlan sahibinin gördüğü sayılar | API: GET /api/v1/listings/{id}/stats (yalnız ilan sahibi Yük Veren)
// BAĞLANTI: ListingService.stats döner → ListingOffersViewModel.stats saklar → Views/ListingOffersView üstte üç kart çizer
struct ListingStats: Decodable {
    let viewCount: Int // ilana bakan Taşımacı sayısı (kişi başına günde bir)
    let favoriteCount: Int // favorileyen Taşımacı sayısı
    let offerCount: Int // gelen teklif sayısı (geri çekilenler hariç)
}
