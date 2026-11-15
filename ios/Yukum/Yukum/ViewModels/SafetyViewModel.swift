//
//  SafetyViewModel.swift
//  Yukum
//
//  Engelle + Şikâyet et (15 Kasım): dört ekranın "⋯" menüsündeki ortak mantık.
//

import Foundation  // [SWIFT] temel türler
import Observation // [SWIFT] @Observable

// ┌─ BAĞLANTI HARİTASI: SafetyViewModel ──────────────────────────────────────────
// │ EKRANLAR : ChatView · ListingDetailView · ShipperProfileView · CarrierProfileView
// │            menü düğmeleri: Views/SafetyViews.swift › SafetyMenuItems | sayfa + onaylar: .safetyFlow(...)
// │ SERVİS   : SafetyServicing → SafetyService → /api/v1/users/{id}/block, /report, /account/blocks
// │ ZİNCİR   : "Şikâyet et" → showReport → ReportSheet → report() → başarı → askBlockAfterReport (engellemek ister misin?)
// │            "Engelle"    → showBlockConfirm → setBlocked(true) → başarı → ekran onBlocked (sohbet/ilan kapanır)
// └──────────────────────────────────────────────────────────────────────
@MainActor
@Observable
final class SafetyViewModel {
    var target: SafetyTarget // var: profil ekranı ad yüklenince target.name günceller
    private let service: SafetyServicing
    init(target: SafetyTarget, service: SafetyServicing = SafetyService()) {
        self.target = target
        self.service = service
    }

    var isBlocked = false          // menüde "Engelle" mi "Engeli kaldır" mı yazsın
    var showReport = false         // şikâyet sayfası açık mı
    var showBlockConfirm = false   // engelle/kaldır onayı
    var askBlockAfterReport = false // şikâyetten sonra "engellemek ister misin?"
    var errorMessage: String?

    // Menü doğru yazsın diye: bu kişi engellediklerim arasında mı? (hata olursa sessiz: menü "Engelle" kalır, sunucu yine doğru davranır)
    func load() async {
        guard !target.userId.isEmpty else { return } // hedef bilinmiyor (eski sunucu cevabı) → menü zaten gizli
        if let list = try? await service.blocked() { isBlocked = list.contains { $0.userId == target.userId } }
    }

    // -> Bool: başarılı mı (ekran animasyonu ve kapanışı buna göre)
    func setBlocked(_ blocked: Bool) async -> Bool {
        errorMessage = nil
        do {
            if blocked { try await service.block(userId: target.userId) } else { try await service.unblock(userId: target.userId) }
            isBlocked = blocked
            return true
        } catch {
            errorMessage = error.userMessage ?? "İşlem yapılamadı."
            return false
        }
    }

    // reasonTitle: kapsüldeki Türkçe yazı (ReportReason.from ile çevrilir) | note boşsa gönderilmez
    // -> String?: hata mesajı (nil = başarılı) → ReportSheet mesajı kendi içinde gösterir
    func report(reasonTitle: String, note: String) async -> String? {
        guard let reason = ReportReason.from(title: reasonTitle) else { return "Şikâyet nedenini seç." }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 500 else { return "Not en fazla 500 karakter olabilir." }
        let body = ReportUserRequest(reason: reason.rawValue, note: trimmed.isEmpty ? nil : trimmed,
                                     listingId: target.listingId, offerId: target.offerId)
        do {
            try await service.report(userId: target.userId, body)
            return nil
        } catch {
            return error.userMessage ?? "Şikâyet gönderilemedi."
        }
    }
}
