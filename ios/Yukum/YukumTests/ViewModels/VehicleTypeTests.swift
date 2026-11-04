//
//  VehicleTypeTests.swift
//  YukumTests
//

import Testing
@testable import Yukum

// Araç türü: API'nin tanıdığı beş değer ve Türkçe başlıkları (iki formda ortak tek kaynak).
struct VehicleTypeTests {
    @Test func apiValuesAndTitlesAreStable() {
        #expect(VehicleType.allCases.map(\.rawValue) == ["Truck", "Lorry", "Pickup", "Refrigerated", "Other"]) // sunucudaki enum ile aynı yazım
        #expect(VehicleType.allCases.map(\.title) == ["Tır", "Kamyon", "Kamyonet", "Frigorifik", "Diğer"])
    }
}
