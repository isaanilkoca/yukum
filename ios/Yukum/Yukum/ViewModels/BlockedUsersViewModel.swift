//
//  BlockedUsersViewModel.swift
//  Yukum
//
//  Profil → Engellediklerim (15 Kasım): liste + engeli kaldır.
//

import Foundation  // [SWIFT] temel türler
import Observation // [SWIFT] @Observable

// ┌─ BAĞLANTI HARİTASI: BlockedUsersViewModel ────────────────────────────────────
// │ EKRAN   : Views/BlockedUsersView ← ProfileView "Engellediklerim" (iki rol)
// │ SERVİS  : SafetyServicing.blocked → GET /api/v1/account/blocks | unblock → DELETE /api/v1/users/{id}/block
// └──────────────────────────────────────────────────────────────────────
@MainActor
@Observable
final class BlockedUsersViewModel {
    private let service: SafetyServicing
    init(service: SafetyServicing = SafetyService()) { self.service = service }

    var users: [BlockedUser] = []
    var errorMessage: String?
    var isLoading = false

    func load() async {
        isLoading = true; defer { isLoading = false }
        errorMessage = nil
        do { users = try await service.blocked() }
        catch { if let message = error.userMessage { errorMessage = message } }
    }

    // -> Bool: başarılı mı (ekran animasyonu için) | başarıda satır listeden hemen düşer (yeniden istek yok)
    func unblock(_ user: BlockedUser) async -> Bool {
        errorMessage = nil
        do {
            try await service.unblock(userId: user.userId)
            users.removeAll { $0.userId == user.userId }
            return true
        } catch {
            errorMessage = error.userMessage ?? "Engel kaldırılamadı."
            return false
        }
    }
}
