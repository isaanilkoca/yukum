//
//  CityService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 26.10.2026.
//

import Foundation // [SWIFT] ağ araçları

// ┌─ BAĞLANTI HARİTASI: CityService (il/ilçe uçları) ────────────────────────────────
// │ ÇAĞIRAN   : ViewModels/HomeViewModel (filtre) | CreateListingViewModel (Kalkış/Varış) — CityServicing sözleşmesi üzerinden
// │ KULLANIR  : Networking/APIClient (authorized: false, herkese açık uçlar) | MODEL: City, District
// │ API       : backend CitiesController: GET /api/v1/cities, GET /api/v1/cities/{id}/districts
// │ SAHTESİ   : YukumTests/Support/FakeCityService.swift
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA: il ve ilçe listelerini API'den getirir. Bu uçlar HERKESE AÇIKTIR: authorized: false → istekte jeton gitmez (kayıt ekranında henüz giriş yok).
// İsteğin kendisi Networking/APIClient.swift'te | kalıplar: Models/Geography/ → City, District
struct CityService {

    private let api = APIClient.shared

    // cities: iller (81) | -> [City]: City listesi döner
    // ÇAĞIRAN: Views/CreateListingView.swift, Views/HomeView.swift (filtre), kayıt ekranları | API: GET /api/v1/cities
    // ⮕ ZİNCİR: ViewModels/HomeViewModel.load() (bir kez) ve CreateListingViewModel.loadCities() ← Views/HomeView / CreateListingView .task | API: GET /api/v1/cities | DÖNEN: [City]
    func cities() async throws -> [City] { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
        try await api.send(.get, "/api/v1/cities", authorized: false, fallback: "Liste yüklenemedi.") // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
    }

    // districts: seçilen ilin ilçeleri | cityId: ilin numarası (plaka kodu, 34 gibi) → City.id'den gelir
    // ÇAĞIRAN: il Picker'ları değişince | API: GET /api/v1/cities/{cityId}/districts
    // ⮕ ZİNCİR: ViewModels/HomeViewModel.cityFilterChanged() ve CreateListingViewModel.fromCityChanged()/toCityChanged() ← il Picker .onChange | API: GET /api/v1/cities/{id}/districts | DÖNEN: [District]
    func districts(cityId: Int) async throws -> [District] {
        try await api.send(.get, "/api/v1/cities/\(cityId)/districts", authorized: false, fallback: "Liste yüklenemedi.") // \( ) = yazının içine değişken koyar
    }
}

// CityService, kendi sözleşmesini karşılar (Services/Protocols/): ViewModel'ler somut sınıfa değil sözleşmeye bağlıdır, testte sahtesi verilir
extension CityService: CityServicing {} // extension [SWIFT]: mevcut türe sonradan özellik/uyum ekler
