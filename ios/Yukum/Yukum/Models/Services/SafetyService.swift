//
//  SafetyService.swift
//  Yukum
//
//  Engelle + Şikâyet et (15 Kasım): API istekleri.
//

import Foundation // [SWIFT] ağ araçları

// ┌─ BAĞLANTI HARİTASI: SafetyService ────────────────────────────────────────
// │ ÇAĞIRAN : ViewModels/SafetyViewModel, ViewModels/BlockedUsersViewModel
// │ API     : PUT/DELETE /api/v1/users/{id}/block · GET /api/v1/account/blocks · POST /api/v1/users/{id}/report (iki rol de; jeton APIClient'ta)
// │ HATALAR : 400 (kendini hedefleme, neden yok) · 404 (kullanıcı yok) → APIError Türkçe mesaj
// │ ETKİ    : engel iki yönlü — mesaj 409, teklif 409, ilan Taşımacı listesinden düşer (backend Application/Accounts/SafetyContracts.cs)
// └──────────────────────────────────────────────────────────────────────
struct SafetyService {
    private let api = APIClient.shared

    func block(userId: String) async throws {
        try await api.sendNoContent(.put, "/api/v1/users/\(userId)/block", fallback: "Engellenemedi.")
    }
    func unblock(userId: String) async throws {
        try await api.sendNoContent(.delete, "/api/v1/users/\(userId)/block", fallback: "Engel kaldırılamadı.")
    }
    func blocked() async throws -> [BlockedUser] {
        try await api.send(.get, "/api/v1/account/blocks", fallback: "Engellenenler alınamadı.")
    }
    func report(userId: String, _ body: ReportUserRequest) async throws {
        try await api.sendNoContent(.post, "/api/v1/users/\(userId)/report", body: body, fallback: "Şikâyet gönderilemedi.")
    }
}
extension SafetyService: SafetyServicing {}
