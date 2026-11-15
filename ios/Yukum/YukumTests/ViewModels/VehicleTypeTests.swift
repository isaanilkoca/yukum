//
//  VehicleTypeTests.swift
//  YukumTests
//

import Testing
@testable import Yukum

// Araç türü: API'nin tanıdığı beş değer ve Türkçe başlıkları (iki formda ortak tek kaynak).
struct VehicleTypeTests {
    @Test func apiValuesAndTitlesAreStable() {
        #expect(VehicleType.allCases.map(\.rawValue) == ["Truck", "Lorry", "Pickup", "Refrigerated", "Other", "Car", "Any"]) // sunucudaki enum ile aynı yazım
        #expect(VehicleType.refrigerated.title == "Frigorifik (soğutuculu)")
        #expect(VehicleType.listingOptions.first == .any)               // ilanda "Farketmez" ilk ve seçilebilir
        #expect(!VehicleType.vehicleOptions.contains(.any))             // araç kaydında ve filtrede yok
        #expect(VehicleType.vehicleOptions.contains(.car))              // şahsi araç eklenebilir
    }
}
