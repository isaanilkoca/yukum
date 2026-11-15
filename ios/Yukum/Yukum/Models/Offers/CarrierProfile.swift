//
//  CarrierProfile.swift
//  Yukum
//

import Foundation

// Taşımacı profili | API: GET /api/v1/carriers/{id} | Decodable [SWIFT]: JSON'dan otomatik doldurulur (alan adları API ile birebir aynı)
// BAĞLANTI: ReviewService.carrierProfile döner → CarrierProfileViewModel saklar → Views/CarrierProfileView çizer
struct CarrierProfile: Decodable {
    let id: String
    let fullName: String // Taşımacı'nın adı
    let about: String? // kısa tanıtım (şimdilik boş gelir) | String?: nil olabilir
    let averageRating: Double // ortalama puan 0–5 | 0 = henüz puan yok
    let ratingCount: Int // kaç kişi puan verdi
    let completedJobCount: Int // tamamlanan iş sayısı
    let reviews: [CarrierReview] // en yeni 20 yorum
    // 15 Kasım (8. adım): sunucu sona ekledi | var + ? : yoksa nil
    var avatarUrl: String? = nil   // ⮕ Design/AvatarView
    var cityName: String? = nil    // bulunduğu il (Hesap Bilgilerim'de seçtiği)
    var memberSince: String? = nil // ISO tarih → "Kasım 2026'dan beri üye"
    var vehicles: [PublicVehicle]? = nil // 15 Kasım: araçları (tür, marka, model, yıl, kapasite; plaka yok) | Optional ŞART: "= []" varsayılanı JSON'da alan yoksa çözümlemeyi düşürür (Decodable varsayılanı kullanmaz)
}

// ─── Yük Veren'in herkese açık profili (15 Kasım, 8. adım) ───
// API: GET /api/v1/shippers/{id} → backend Application/Reviews/GetShipperProfileHandler.cs (ShipperProfileDto)
// GİZLİLİK: telefon/e-posta/vergi bilgisi sunucudan hiç gelmez
// ⮕ KULLANIM [ShipperPublicProfile]: ReviewService.shipperProfile, ShipperProfileViewModel, ShipperProfileView
nonisolated struct ShipperPublicProfile: Decodable {
    let id: String
    let fullName: String
    let avatarUrl: String?
    let companyName: String?
    let cityName: String?
    let about: String?
    let memberSince: String
    let completedListingCount: Int
    let openListingCount: Int
}

// Profildeki tek yorum | Hashable [SWIFT]: ForEach(id: \.self) ile satır kimliği olarak kullanılabilir (API yorumlara ayrı numara vermez)
struct CarrierReview: Decodable, Hashable {
    let rating: Int // 1–5
    let comment: String? // yorum yoksa nil
    let shipperName: String // puanı veren, kısaltılmış ("Ali V.")
    let listingTitle: String // hangi iş için
    let fromCityName: String // rota
    let toCityName: String
    let createdAt: String // ISO tarih yazısı | ekranda ilk 10 karakter (yyyy-MM-dd) gösterilir
}
