//
//  CityService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 26.10.2026.
//

import Foundation // [SWIFT] ağ araçları

// ┌─ BAĞLANTI HARİTASI: CityService (il/ilçe uçları) ────────────────────────────────
// │ ÇAĞIRAN   : Features/Listings/HomeViewModel (filtre) | CreateListingViewModel (Kalkış/Varış) — CityServicing sözleşmesi üzerinden
// │ KULLANIR  : Core/Networking/APIClient (authorized: false, herkese açık uçlar) | MODEL: City, District
// │ API       : backend CitiesController: GET /api/v1/cities, GET /api/v1/cities/{id}/districts
// │ SAHTESİ   : YukumTests/Support/FakeCityService.swift
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA: il ve ilçe listelerini API'den getirir. Bu uçlar HERKESE AÇIKTIR: authorized: false → istekte jeton gitmez (kayıt ekranında henüz giriş yok).
// İsteğin kendisi Core/Networking/APIClient.swift'te | kalıplar: Models/Geography/ → City, District
// ⮕ KULLANIM [CityService]: kullanır: CreateListingViewModel › init(), HomeViewModel › init()
struct CityService {

    // ⮕ KULLANIM [api]: okur: CityService › cities(), CityService › districts()
    private let api = APIClient.shared

    // cities: iller (81) | -> [City]: City listesi döner
    // ÇAĞIRAN: Features/Listings/CreateListingView.swift, Features/Listings/HomeView.swift (filtre), kayıt ekranları | API: GET /api/v1/cities
    // ⮕ ZİNCİR: Features/Listings/HomeViewModel.load() (bir kez) ve CreateListingViewModel.loadCities() ← Features/Listings/HomeView / CreateListingView .task | API: GET /api/v1/cities | DÖNEN: [City]
    // ⮕ KULLANIM [cities]: çağırır: CreateListingViewModel › loadCities(), HomeViewModel › load()
    func cities() async throws -> [City] { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
        try await api.send(.get, "/api/v1/cities", authorized: false, fallback: "Liste yüklenemedi.") // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
    }

    // districts: seçilen ilin ilçeleri | cityId: ilin numarası (plaka kodu, 34 gibi) → City.id'den gelir
    // ÇAĞIRAN: il Picker'ları değişince | API: GET /api/v1/cities/{cityId}/districts
    // ⮕ ZİNCİR: Features/Listings/HomeViewModel.cityFilterChanged() ve CreateListingViewModel.fromCityChanged()/toCityChanged() ← il Picker .onChange | API: GET /api/v1/cities/{id}/districts | DÖNEN: [District]
    // ⮕ KULLANIM [districts]: çağırır: CreateListingViewModel › fromCityChanged(), CreateListingViewModel › toCityChanged(), HomeViewModel › cityFilterChanged()
    func districts(cityId: Int) async throws -> [District] {
        try await api.send(.get, "/api/v1/cities/\(cityId)/districts", authorized: false, fallback: "Liste yüklenemedi.") // \( ) = yazının içine değişken koyar
    }
}

// CityService, kendi sözleşmesini karşılar (Services/Protocols/): ViewModel'ler somut sınıfa değil sözleşmeye bağlıdır, testte sahtesi verilir
extension CityService: CityServicing {} // extension [SWIFT]: mevcut türe sonradan özellik/uyum ekler
