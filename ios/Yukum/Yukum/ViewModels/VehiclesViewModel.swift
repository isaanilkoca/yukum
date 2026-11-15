//
//  VehiclesViewModel.swift
//  Yukum
//
//  Araçlarım (15 Kasım): liste, ekle, düzenle, sil.
//

import Foundation // [SWIFT] temel türler
import Observation // [SWIFT] @Observable

// ┌─ BAĞLANTI HARİTASI: VehiclesViewModel ───────────────────────────────────
// │ EKRAN   : Views/VehiclesView (liste) + VehicleFormSheet (ekle/düzenle)
// │ SERVİS  : VehicleServicing → VehicleService → /api/v1/vehicles
// │ KURAL   : plaka zorunlu (biçim ve tekillik sunucuda), tür zorunlu, kapasite isteğe bağlı
// └──────────────────────────────────────────────────────────────────────
@MainActor
@Observable
final class VehiclesViewModel {
    private let service: VehicleServicing
    init(service: VehicleServicing = VehicleService()) { self.service = service }

    var vehicles: [Vehicle] = []
    var errorMessage: String?
    var isLoading = false

    func load() async {
        isLoading = true; defer { isLoading = false }
        errorMessage = nil
        do { vehicles = try await service.mine() }
        catch { if let message = error.userMessage { errorMessage = message } }
    }

    // save: ekle (editing nil) ya da düzenle | ön kontrol: tür + plaka boş olmasın, kapasite yazıldıysa sayı olsun (asıl kurallar sunucuda)
    // -> String?: hata mesajı (nil = başarılı) → form sayfası mesajı kendi içinde gösterir, başarılıysa kapanır
    // 15 Kasım: marka, model, yıl ZORUNLU (Yük Veren teklifte ve profilde aracın kalitesini/yaşını görür) | asıl kural sunucuda (SaveVehicleHandler)
    func save(editing: Vehicle?, type: String, plate: String, capacity: String, brand: String, model: String, year: String) async -> String? {
        let plate = plate.trimmingCharacters(in: .whitespaces)
        let capacityText = capacity.trimmingCharacters(in: .whitespaces)
        let brand = brand.trimmingCharacters(in: .whitespaces), model = model.trimmingCharacters(in: .whitespaces)
        guard !type.isEmpty else { return "Araç türünü seç." }
        guard !plate.isEmpty else { return "Plaka zorunlu." }
        guard !brand.isEmpty else { return "Marka zorunlu." }
        guard !model.isEmpty else { return "Model zorunlu." }
        let maxYear = Calendar.current.component(.year, from: Date()) + 1
        guard let yearValue = Int(year.trimmingCharacters(in: .whitespaces)), (1970...maxYear).contains(yearValue) else {
            return "Model yılı 1970 ile \(maxYear) arasında olmalı."
        }
        var kg: Int? = nil
        if !capacityText.isEmpty {
            guard let value = Int(capacityText), value > 0 else { return "Kapasite sayı olmalı (kg)." }
            kg = value
        }
        let body = VehicleBody(type: type, plateNumber: plate, capacityKg: kg, brand: brand, model: model, year: yearValue)
        do {
            if let editing { _ = try await service.update(id: editing.id, body) } else { _ = try await service.add(body) }
            await load()
            return nil
        } catch {
            return error.userMessage ?? "Kaydedilemedi."
        }
    }

    func delete(_ vehicle: Vehicle) async -> Bool {
        errorMessage = nil
        do { try await service.delete(id: vehicle.id); await load(); return true }
        catch { if let message = error.userMessage { errorMessage = message }; return false }
    }
}
