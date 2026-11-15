//
//  Safety.swift
//  Yukum
//
//  Engelle + Şikâyet et modelleri (15 Kasım, Apple kuralı 1.2: kullanıcılar arası içerikte ikisi de şart).
//

import Foundation // [SWIFT] temel türler

// ┌─ BAĞLANTI HARİTASI: Safety modelleri ─────────────────────────────────────────
// │ ReportReason      → Views/ReportSheet (neden kapsülleri) → ReportUserRequest.reason
// │ ReportUserRequest → SafetyService.report → POST /api/v1/users/{id}/report (backend ReportUserHandler)
// │ BlockedUser       ← SafetyService.blocked ← GET /api/v1/account/blocks → Views/BlockedUsersView
// │ SafetyTarget      → ViewModels/SafetyViewModel (kimi hedefliyoruz + nereden)
// └──────────────────────────────────────────────────────────────────────

// Şikâyet nedeni | rawValue sunucunun beklediği yazı (backend Domain/Accounts/ReportReason) | title ekranda görünen Türkçe
// CaseIterable [SWIFT]: allCases ile bütün seçenekler sırayla gelir → kapsül listesi
// ⮕ KULLANIM [ReportReason]: ReportSheet, SafetyViewModel
enum ReportReason: String, CaseIterable {
    case fraud = "Fraud"
    case harassment = "Harassment"
    case fakeListing = "FakeListing"
    case spam = "Spam"
    case other = "Other"

    var title: String {
        switch self {
        case .fraud: "Dolandırıcılık"
        case .harassment: "Hakaret / taciz"
        case .fakeListing: "Sahte ilan"
        case .spam: "Spam / reklam"
        case .other: "Diğer"
        }
    }

    // Kapsülden gelen Türkçe yazı → neden | FlowChips [String] ile çalıştığı için geri çeviri gerekir
    static func from(title: String) -> ReportReason? { allCases.first { $0.title == title } }
}

// POST /api/v1/users/{id}/report gövdesi | listingId/offerId: şikâyet hangi ilan/sohbetten geldi (yönetici incelemesini kolaylaştırır)
struct ReportUserRequest: Encodable {
    let reason: String
    let note: String?
    let listingId: String?
    let offerId: String?
}

// Engellediğim kişi | GET /api/v1/account/blocks satırı
// ⮕ KULLANIM [BlockedUser]: BlockedUsersViewModel, BlockedUsersView
struct BlockedUser: Decodable, Identifiable {
    let userId: String
    let fullName: String
    let blockedAt: String
    var id: String { userId } // Identifiable [SWIFT]: ForEach satırları buna göre ayırır
}

// Engelle/şikâyet menüsünün hedefi | NEDEN struct: dört ekran (sohbet, ilan detayı, iki profil) aynı bilgiyi aynı biçimde verir
// ⮕ KULLANIM [SafetyTarget]: ChatView, ListingDetailView, ShipperProfileView, CarrierProfileView → SafetyViewModel
struct SafetyTarget {
    let userId: String       // engellenecek / şikâyet edilecek kişi
    var name: String         // onay penceresinde görünen ad | var: profil ekranları adı yükleyince günceller
    var listingId: String? = nil // ilan detayından geldiyse
    var offerId: String? = nil   // sohbetten geldiyse
}
