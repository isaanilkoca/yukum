//
//  OpenListingsFilterTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// Liste filtresinin adrese çevrilmesi ve sayfa zarfının JSON'dan okunması. Sunucu gerekmez.
struct OpenListingsFilterTests {

    // [URLQueryItem] → ["ad": "değer"] sözlüğü: sıradan bağımsız karşılaştırmak için
    private func dict(_ items: [URLQueryItem]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test func emptyFilter_sendsOnlyPaging() {
        let items = OpenListingsFilter().queryItems(page: 1, pageSize: 20, lat: nil, lon: nil)
        #expect(dict(items) == ["page": "1", "pageSize": "20"]) // boş filtre adrese hiçbir koşul eklemez
    }

    @Test func filledFilter_sendsEveryFieldWithTheApiParameterName() {
        let filter = OpenListingsFilter(fromCityId: 33, fromDistrictId: 7, toCityId: 34, minBudget: 1000, maxBudget: 9000,
                                        vehicleType: "Truck", pickupFrom: "2026-11-01", pickupTo: "2026-11-30", sort: .priceDesc)
        let sent = dict(filter.queryItems(page: 3, pageSize: 20, lat: 36.8, lon: 34.6))
        #expect(sent == ["page": "3", "pageSize": "20", "fromCityId": "33", "fromDistrictId": "7", "toCityId": "34",
                         "minBudget": "1000", "maxBudget": "9000", "vehicleType": "Truck",
                         "pickupFrom": "2026-11-01", "pickupTo": "2026-11-30", "sort": "PriceDesc", "lat": "36.8", "lon": "34.6"])
    }

    @Test func location_isSentOnlyWhenBothPartsExist() {
        let onlyLat = dict(OpenListingsFilter().queryItems(page: 1, pageSize: 20, lat: 36.8, lon: nil))
        #expect(onlyLat["lat"] == nil && onlyLat["lon"] == nil) // API tek parçayı 400 ile reddeder, hiç göndermiyoruz
    }

    @Test func sortOptions_haveApiValuesAndTurkishTitles() {
        #expect(ListingSort.allCases.map(\.rawValue) == ["Newest", "PriceAsc", "PriceDesc"])
        #expect(ListingSort.allCases.map(\.title) == ["En yeni", "Fiyat (artan)", "Fiyat (azalan)"])
    }

    @Test func pageEnvelope_decodesFromTheApiJson() throws {
        let json = """
        {"items":[{"id":"a1","title":"20 palet","weightKg":1000,"fromCityName":"Mersin","fromDistrictName":"Mezitli",
                   "toCityName":"İstanbul","toDistrictName":"Kadıköy","pickupDate":"2026-12-01","budget":5000.0,
                   "myOfferAmount":null,"myOfferStatus":null,"distanceKm":12.5,
                   "description":null,"vehicleType":"Truck","fromCityId":33,"fromDistrictId":1,"toCityId":34,"toDistrictId":2,"isFavorite":false}],
         "page":2,"pageSize":20,"totalCount":41}
        """
        let page = try JSONDecoder().decode(Page<Listing>.self, from: Data(json.utf8))
        #expect(page.page == 2 && page.pageSize == 20 && page.totalCount == 41)
        #expect(page.items.count == 1 && page.items[0].title == "20 palet" && page.items[0].distanceKm == 12.5)
    }

    @Test func extraCount_countsOnlyTheFilterSheetFields() {
        #expect(OpenListingsFilter().extraCount == 0)
        #expect(OpenListingsFilter(fromCityId: 33, fromDistrictId: 7).extraCount == 0) // kalkış ana ekranda, sayılmaz
        var f = OpenListingsFilter()
        f.toCityId = 34; f.minBudget = 1000; f.vehicleType = "Truck"; f.sort = .priceAsc
        #expect(f.extraCount == 4)
    }

    @MainActor
    @Test func filterSheetDate_roundTripsInTheApiFormat() {
        let date = OpenListingsFilterView.parse("2026-12-05")
        #expect(date != nil)
        #expect(OpenListingsFilterView.format(date!) == "2026-12-05")
        #expect(OpenListingsFilterView.parse("bozuk") == nil)
    }
}
