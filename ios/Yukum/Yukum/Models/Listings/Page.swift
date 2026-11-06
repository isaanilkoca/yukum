//
//  Page.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 6.11.2026.
//

import Foundation

// API'nin sayfa zarfı: { items, page, pageSize, totalCount }
// <Item: Decodable> [SWIFT]: generic, her liste türü için tek kalıp (Page<Listing>, ...)
// BAĞLANTI: APIClient.send JSON'u buna çevirir ← ListingService.openListings döner → HomeViewModel.load() okur
struct Page<Item: Decodable>: Decodable {
    let items: [Item]
    let page: Int
    let pageSize: Int
    let totalCount: Int // filtreye uyan TÜM kayıt | "başka sayfa var mı" = yüklenen sayı < totalCount
}
