//
//  VehicleServicing.swift
//  Yukum
//

import Foundation

// Araçlarım servisinin sözleşmesi (15 Kasım) | ViewModel somut sınıfa değil buna bağlıdır, testte sahtesi verilir
// ⮕ KULLANIM [VehicleServicing]: VehiclesViewModel
protocol VehicleServicing {
    func mine() async throws -> [Vehicle]
    func add(_ body: VehicleBody) async throws -> Vehicle
    func update(id: String, _ body: VehicleBody) async throws -> Vehicle
    func delete(id: String) async throws
}
