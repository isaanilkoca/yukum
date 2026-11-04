//
//  CityService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 26.10.2026.
//

import Foundation // [SWIFT] ağ araçları

// BU DOSYA: il ve ilçe listelerini API'den getirir. Bu uçlar HERKESE AÇIKTIR: authorized: false → istekte jeton gitmez (kayıt ekranında henüz giriş yok).
// İsteğin kendisi Networking/APIClient.swift'te | kalıplar: Models/Geography/ → City, District
struct CityService {

    private let api = APIClient.shared

    // cities: iller (81) | -> [City]: City listesi döner
    // ÇAĞIRAN: Views/CreateListingView.swift, Views/HomeView.swift (filtre), kayıt ekranları | API: GET /api/v1/cities
    func cities() async throws -> [City] {
        try await api.send(.get, "/api/v1/cities", authorized: false, fallback: "Liste yüklenemedi.")
    }

    // districts: seçilen ilin ilçeleri | cityId: ilin numarası (plaka kodu, 34 gibi) → City.id'den gelir
    // ÇAĞIRAN: il Picker'ları değişince | API: GET /api/v1/cities/{cityId}/districts
    func districts(cityId: Int) async throws -> [District] {
        try await api.send(.get, "/api/v1/cities/\(cityId)/districts", authorized: false, fallback: "Liste yüklenemedi.") // \( ) = yazının içine değişken koyar
    }
}

// CityService, kendi sözleşmesini karşılar (Services/Protocols/): ViewModel'ler somut sınıfa değil sözleşmeye bağlıdır, testte sahtesi verilir
extension CityService: CityServicing {}
