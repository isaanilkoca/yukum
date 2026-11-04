//
//  FakeLocation.swift
//  YukumTests
//

import Foundation
@testable import Yukum

// Sahte konum: GPS/izin penceresi olmadan "konum şu, izin reddedildi, hata" durumlarını denemek için (Core/Location/LocationProviding sözleşmesini karşılar)
final class FakeLocation: LocationProviding {
    var latitude: Double?
    var longitude: Double?
    var isDenied = false
    var errorMessage: String?
    private(set) var requestCalls = 0 // request() kaç kez çağrıldı
    func request() { requestCalls += 1 }
}
