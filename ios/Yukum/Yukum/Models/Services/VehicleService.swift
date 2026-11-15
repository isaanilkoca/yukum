//
//  VehicleService.swift
//  Yukum
//
//  Araçlarım (15 Kasım): Taşımacı'nın araçları için API istekleri.
//

import Foundation // [SWIFT] ağ araçları

// ┌─ BAĞLANTI HARİTASI: VehicleService ───────────────────────────────────────
// │ ÇAĞIRAN : ViewModels/VehiclesViewModel
// │ API     : GET/POST /api/v1/vehicles, PUT/DELETE /api/v1/vehicles/{id} (yalnız Taşımacı; jeton APIClient'ta eklenir)
// │ HATALAR : 400 (plaka/tür) ve 409 (aynı plaka, 20 araç sınırı) Türkçe mesajla gelir → APIError
// └──────────────────────────────────────────────────────────────────────
struct VehicleService {
    private let api: APIClient
    // init(api:): varsayılan ortak istemci (uygulama değişmez) | testte sahte ağlı istemci verilir → hangi adrese hangi istek gittiği sınanır (YukumTests/Networking/ServiceContractTests)
    init(api: APIClient = .shared) { self.api = api }

    func mine() async throws -> [Vehicle] {
        try await api.send(.get, "/api/v1/vehicles", fallback: "Araçlar alınamadı.")
    }
    func add(_ body: VehicleBody) async throws -> Vehicle {
        try await api.send(.post, "/api/v1/vehicles", body: body, fallback: "Araç eklenemedi.")
    }
    func update(id: String, _ body: VehicleBody) async throws -> Vehicle {
        try await api.send(.put, "/api/v1/vehicles/\(id)", body: body, fallback: "Araç güncellenemedi.")
    }
    func delete(id: String) async throws {
        try await api.sendNoContent(.delete, "/api/v1/vehicles/\(id)", fallback: "Araç silinemedi.")
    }
}
extension VehicleService: VehicleServicing {}
