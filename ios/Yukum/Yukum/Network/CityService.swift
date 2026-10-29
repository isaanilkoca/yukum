//
//  CityService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 29.10.2026.
//

import Foundation // Swift'in hazır ağ araçları bu kütüphanede

// BU DOSYA NE İŞE YARAR? İl ve ilçe listesini API'den çeker. Giriş (token) gerektirmez.
// AuthService'ten ayrı çünkü o POST yapıyor (veri gönderiyor), bu GET yapıyor (veri istiyor).
//
// BAĞLANTI (akış): View/CreateListingView.swift → CityService().cities() çağırır → burası API'ye gider → JSON döner →
// Network/CityModels.swift'teki City/District kalıbına çevrilir → [City] olarak ekrana geri verilir.
struct CityService {

    private let baseURL = "http://localhost:5054" // AuthService'teki baseURL ile aynı adres (canlıya çıkarken ikisi birlikte değişecek)

    // cities: iller | async: cevabı bekler, ekran donmaz | throws: hata fırlatabilir | -> [City]: City listesi döner
    // ÇAĞIRAN: View/CreateListingView.swift (.task içinde) → CityService().cities()
    // City'nin kalıbı: Network/CityModels.swift → struct City
    func cities() async throws -> [City] {

        try await get ("/api/v1/cities") // "/api/v1/cities" = API'deki il listesi odası → aşağıdaki get'e gider

    }

    // districts: seçilen ilin ilçeleri | cityId: ilin numarası (34 gibi) → City.id'den gelir
    // ÇAĞIRAN: View/CreateListingView.swift (il seçilince, sonraki adım) | District kalıbı: Network/CityModels.swift
    func districts(cityId: Int) async throws -> [District] {

        try await get ("/api/v1/cities/\(cityId)/districts") // \( ) = yazının içine değişken koyar
    }

    // Üstteki iki fonksiyonun ortak işi: adrese GET at, cevabı çevir (AuthService.post'un GET karşılığı).
    // <Response: Decodable>: dönen türü Swift çağrıdan anlar ([City] ya da [District])
    private func get<Response: Decodable>(_ path: String) async throws -> Response {
        let url = URL(string: baseURL + path)! // yazıyı adrese çevirir | baseURL + path: ana adres + oda
        let (data, response) = try await URLSession.shared.data(from: url) // .data(from:) [SWIFT]: adrese GET atar (zarf hazırlamak gerekmez) | await: bekle
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0 // sunucunun notu, 200 = tamam
        if status != 200 {
            throw AuthError(message: "Liste yüklenemedi.") // AuthError: Network/AuthService.swift'te tanımlı; ekran yakalayıp gösterir
        }
        return try JSONDecoder().decode(Response.self, from: data) // JSON'u struct'a çevir
    }
}
