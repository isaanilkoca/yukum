//
//  OpenListingsFilter.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 6.11.2026.
//

import Foundation


// Liste filtresi tek pakette | 0 / nil / "" = filtre yok (adrese yazılmaz)
// NEDEN paket: servis fonksiyonu 10 parametre almasın, ViewModel filtreyi tek değişkende tutsun
// Equatable [SWIFT]: iki filtre == ile karşılaştırılır
// BAĞLANTI: HomeViewModel doldurur → ListingService.openListings → queryItems → GET /api/v1/listings?...

struct OpenListingsFilter: Equatable {
    var fromCityId = 0
    var fromDistrictId = 0
    var toCityId = 0
    var minBudget: Int?        // Int?: boş olabilir
    var maxBudget: Int?
    var vehicleType = ""       // VehicleType.rawValue ("Truck"...)
    var pickupFrom: String?    // API biçimi "2026-11-05"
    var pickupTo: String?
    var sort: ListingSort?     // nil = sunucu seçer (konum varsa en yakın, yoksa en yeni)
    var matchMyVehicles = false // 15 Kasım: yalnız araçlarıma uygun ilanlar (sunucu: ilan türü araçlarımdan birinde var ya da "Farketmez")
    // 15 Kasım (sahibinden tarzı): konuma uzaklık + ağırlık aralığı — diğer filtrelerle BİRLİKTE çalışır
    var maxDistanceKm: Int?     // konumuma en çok X km | konum yoksa gönderilmez (sunucu konumsuz uzaklığı 400 ile reddeder)
    var minWeightKg: Int?
    var maxWeightKg: Int?
    static let distanceOptions = [25, 50, 100, 250, 500] // filtre sayfasındaki seçenekler (km)

    // extraCount: Filtre sayfasındaki dolu alan sayısı (rozet için) | kalkış il/ilçesi ana ekranda göründüğü için sayılmaz
    var extraCount: Int {
        [toCityId != 0, minBudget != nil, maxBudget != nil, !vehicleType.isEmpty, pickupFrom != nil, pickupTo != nil, matchMyVehicles,
         maxDistanceKm != nil, minWeightKg != nil || maxWeightKg != nil].filter { $0 }.count // [Bool].filter{$0}: doğruları say
    }

    // Filtreyi adresin ?'ten sonraki kısmına çevirir | URLQueryItem [SWIFT, Foundation]: "ad=değer" çifti
    // Adlar API'deki parametre adlarıyla birebir aynı olmalı | lat+lon yalnız ikisi birlikte gider (API tek parçayı 400 ile reddeder)
    func queryItems(page: Int, pageSize: Int, lat: Double?, lon: Double?) -> [URLQueryItem] {
        var items = [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "pageSize", value: String(pageSize))]
        if fromCityId != 0 { items.append(URLQueryItem(name: "fromCityId", value: String(fromCityId))) }
        if fromDistrictId != 0 { items.append(URLQueryItem(name: "fromDistrictId", value: String(fromDistrictId))) }
        if toCityId != 0 { items.append(URLQueryItem(name: "toCityId", value: String(toCityId))) }
        if let minBudget { items.append(URLQueryItem(name: "minBudget", value: String(minBudget))) } // if let [SWIFT]: nil değilse içini aç
        if let maxBudget { items.append(URLQueryItem(name: "maxBudget", value: String(maxBudget))) }
        if !vehicleType.isEmpty { items.append(URLQueryItem(name: "vehicleType", value: vehicleType)) }
        if let pickupFrom { items.append(URLQueryItem(name: "pickupFrom", value: pickupFrom)) }
        if let pickupTo { items.append(URLQueryItem(name: "pickupTo", value: pickupTo)) }
        if let sort { items.append(URLQueryItem(name: "sort", value: sort.rawValue)) }
        if matchMyVehicles { items.append(URLQueryItem(name: "matchMyVehicles", value: "true")) }
        if let minWeightKg { items.append(URLQueryItem(name: "minWeightKg", value: String(minWeightKg))) }
        if let maxWeightKg { items.append(URLQueryItem(name: "maxWeightKg", value: String(maxWeightKg))) }
        if let maxDistanceKm, lat != nil, lon != nil { items.append(URLQueryItem(name: "maxDistanceKm", value: String(maxDistanceKm))) } // konum yoksa gönderilmez
        if let lat, let lon {
            items.append(URLQueryItem(name: "lat", value: String(lat)))
            items.append(URLQueryItem(name: "lon", value: String(lon)))
        }
        return items
    }
}
