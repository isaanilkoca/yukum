//
//  PriceReference.swift
//  Yukum
//

import Foundation

// Emsal fiyat cevabı | API: GET /api/v1/price-reference?fromCityId=..&toCityId=..&vehicleType=.. | Decodable [SWIFT]: JSON'dan otomatik doldurulur
// BAĞLANTI: ListingService.priceReference döner → ListingDetailViewModel saklar → Views/ListingDetailView "Bu rotada emsal fiyat" yazar
struct PriceReference: Decodable {
    let medianAmount: Double? // son tamamlanan işlerin medyan tutarı | Double?: yeterli iş (en az 3) yoksa sunucu null yollar → nil → hiçbir şey gösterilmez
    let sampleCount: Int // hesaba katılan tamamlanmış iş sayısı
}
