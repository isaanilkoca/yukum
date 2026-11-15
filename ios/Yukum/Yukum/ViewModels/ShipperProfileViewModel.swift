//
//  ShipperProfileViewModel.swift
//  Yukum
//
//  Yük Veren profili (15 Kasım, 8. adım): Taşımacı ilan detayından Yük Veren'e dokununca.
//

import Foundation  // [SWIFT] temel türler
import Observation // [SWIFT] @Observable

// ┌─ BAĞLANTI HARİTASI: ShipperProfileViewModel ──────────────────────────────────
// │ EKRAN   : Views/ShipperProfileView ← ListingDetailView ("Yük Veren" satırı; listing.shipperId)
// │ SERVİS  : ReviewServicing.shipperProfile → GET /api/v1/shippers/{id} → backend GetShipperProfileHandler
// │           → AspNetUsers + ShipperProfiles (açık alanlar) + Listings (COUNT) | telefon/e-posta/vergi bilgisi gelmez
// └──────────────────────────────────────────────────────────────────────
@MainActor
@Observable
final class ShipperProfileViewModel {
    let shipperId: String
    private let service: ReviewServicing
    init(shipperId: String, service: ReviewServicing = ReviewService()) {
        self.shipperId = shipperId
        self.service = service
    }

    var profile: ShipperPublicProfile?
    var errorMessage: String?

    func load() async {
        errorMessage = nil
        do { profile = try await service.shipperProfile(id: shipperId) }
        catch { if let message = error.userMessage { errorMessage = message } }
    }
}

// "2026-03-01T10:00:00Z" → "Mart 2026" | iki profil ekranı da kullanır (Taşımacı + Yük Veren)
// ISO8601DateFormatter [SWIFT]: sunucunun tarih yazısını Date'e çevirir; kesirli saniyeli ve kesirsiz iki biçim denenir
// ⮕ KULLANIM [MemberSince]: ShipperProfileView, CarrierProfileView
enum MemberSince {
    nonisolated static func text(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = parser.date(from: iso)
        if date == nil { parser.formatOptions = [.withInternetDateTime]; date = parser.date(from: iso) }
        if date == nil { parser.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]; date = parser.date(from: String(iso.prefix(19))) } // saat dilimsiz (SQL DateTime)
        guard let date, Calendar(identifier: .gregorian).component(.year, from: date) > 2000 else { return nil } // varsayılan tarih (0001) gösterilmez
        let out = DateFormatter()
        out.locale = Locale(identifier: "tr_TR")
        out.dateFormat = "LLLL yyyy" // LLLL: tek başına ay adı ("Mart")
        return out.string(from: date)
    }
}
