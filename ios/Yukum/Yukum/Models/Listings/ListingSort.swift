//
//  ListingSort.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 6.11.2026.
//

import Foundation

// Sıralama seçenekleri | rawValue = API'deki sort değeri (birebir aynı olmalı) | "En yakın" yok: konum açıkken sunucu seçer
// CaseIterable [SWIFT]: allCases ile Picker'ı doldururuz | Identifiable [SWIFT]: ForEach'te id gerekmez
// BAĞLANTI: OpenListingsFilter.sort → ListingService adrese ekler | sıralama Picker'ı sonraki adımda HomeView'da

enum ListingSort: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case priceAsc = "PriceAsc"
    case priceDesc = "PriceDesc"
    case pickupSoonest = "PickupSoonest" // 15 Kasım: yükleme tarihi en yakın (backend ListingSort.PickupSoonest)

    var id: String { rawValue }
    var title: String { // ekrandaki Türkçe ad
        switch self {
        case .newest: "En yeni"
        case .priceAsc: "Fiyat (artan)"
        case .priceDesc: "Fiyat (azalan)"
        case .pickupSoonest: "Yükleme tarihi (en yakın)"
        }
    }
}
