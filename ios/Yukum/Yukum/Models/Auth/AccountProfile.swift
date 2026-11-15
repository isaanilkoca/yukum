//
//  AccountProfile.swift
//  Yukum
//
//  Hesap Bilgilerim (15 Kasım): sunucudan okunan hesap + giden güncelleme paketi + fotoğraf yükleme cevabı.
//

import Foundation // [SWIFT] temel türler

// ┌─ BAĞLANTI HARİTASI: AccountProfile.swift ────────────────────────────────────
// │ API (backend): Application/Accounts/AccountProfileHandlers.cs → AccountProfileDto / UpdateAccountProfileRequest (alan adları BİREBİR aynı)
// │ GELDİĞİ YER  : GET/PUT /api/v1/account/me → AccountService.profile()/update() → AccountInfoViewModel.profile
// │ DB (sunucu)  : AspNetUsers (ad, e-posta, telefon, avatarUrl) + ShipperProfiles / CarrierProfiles (rol alanları)
// └──────────────────────────────────────────────────────────────────────

// Sunucunun gönderdiği hesap bilgisi | rolün kullanmadığı alanlar null gelir → Swift'te Optional (?)
// nonisolated [SWIFT]: proje varsayılanı MainActor; model arka planda (JSON çözümü) da kullanılabilsin
// ⮕ KULLANIM [AccountProfile]: AccountService, AccountInfoViewModel, AccountInfoView
nonisolated struct AccountProfile: Decodable, Equatable {
    let id: String
    let role: String          // "Shipper" / "Carrier"
    let fullName: String
    let email: String         // salt okunur: e-posta değiştirilemez (doğrulama e-postası yok)
    let phone: String         // "+905321234567" biçiminde gelir
    let avatarUrl: String?    // "/api/v1/avatars/{id}" (göreli) | nil = fotoğraf yok
    let cityId: Int?          // Yük Veren: CityId | Taşımacı: HomeCityId (sunucu ikisini tek alanda verir)
    let about: String?
    let companyName: String?  // ─ yalnız Yük Veren
    let taxNumber: String?
    let taxOffice: String?
    let averageRating: Double? // ─ yalnız Taşımacı, salt okunur
    let ratingCount: Int?
    let completedJobCount: Int?

    var isShipper: Bool { role == "Shipper" }
}

// PUT /api/v1/account/me gövdesi | Encodable [SWIFT]: JSON'a çevrilir; nil alanlar JSON'a null olarak değil HİÇ yazılmaz (sunucu null sayar)
// currentPassword: yalnız telefon değiştiyse dolu (sunucu ister; yanlışsa 400 "Şifre hatalı.")
nonisolated struct UpdateAccountProfileRequest: Encodable, Equatable {
    let fullName: String
    let phone: String
    let currentPassword: String?
    let cityId: Int?
    let about: String?
    let companyName: String?
    let taxNumber: String?
    let taxOffice: String?
}

// POST /api/v1/account/avatar cevabı: { "avatarUrl": "/api/v1/avatars/{id}" }
nonisolated struct AvatarResponse: Decodable {
    let avatarUrl: String
}
