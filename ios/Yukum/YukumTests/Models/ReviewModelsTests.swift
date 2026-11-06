//
//  ReviewModelsTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// API'den gelen JSON'un yeni alanlarla doğru çözüldüğünü doğrular (alan adı yazım hatası = sessizce bozuk ekran)
struct ReviewModelsTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    @Test func carrierProfile_decodes_withAndWithoutComment() throws {
        let profile = try decode(CarrierProfile.self, """
        {"id":"c1","fullName":"Veli Nakliyat","about":null,"averageRating":4.50,"ratingCount":2,"completedJobCount":3,
         "reviews":[{"rating":5,"comment":"Harika","shipperName":"Ali V.","listingTitle":"Mobilya","fromCityName":"Mersin","toCityName":"İstanbul","createdAt":"2026-11-07T10:00:00Z"},
                    {"rating":3,"comment":null,"shipperName":"Ayşe K.","listingTitle":"Koli","fromCityName":"Adana","toCityName":"Ankara","createdAt":"2026-11-06T09:00:00Z"}]}
        """)
        #expect(profile.averageRating == 4.5)
        #expect(profile.ratingCount == 2 && profile.completedJobCount == 3)
        #expect(profile.about == nil)
        #expect(profile.reviews.map(\.rating) == [5, 3])
        #expect(profile.reviews[1].comment == nil)
    }

    @Test func offerRows_decode_theNewStageAndRatingFields() throws {
        let carrierOffer = try decode(CarrierOffer.self, """
        {"id":"o1","listingId":"l1","listingTitle":"İlan","fromCityName":"Mersin","fromDistrictName":"Mezitli","toCityName":"İstanbul","toDistrictName":"Kadıköy",
         "shipperName":"Ali","weightKg":1000,"pickupDate":"2026-12-01","amount":1000.0,"note":null,"status":"Accepted","isNew":false,"stage":"InTransit"}
        """)
        #expect(carrierOffer.stage == "InTransit")

        let history = try decode(ShipperHistoryOffer.self, """
        {"id":"o1","listingTitle":"İlan","fromCityName":"Mersin","fromDistrictName":"Mezitli","toCityName":"İstanbul","toDistrictName":"Kadıköy","weightKg":1000,
         "pickupDate":"2026-12-01","carrierName":"Veli","amount":1000.0,"status":"Completed","stage":"Delivered","carrierId":"c1","reviewed":true}
        """)
        #expect(history.stage == "Delivered" && history.carrierId == "c1" && history.reviewed)

        let offer = try decode(ListingOffer.self, """
        {"id":"o1","carrierName":"Veli","amount":900.0,"note":null,"status":"Pending","carrierId":"c1","carrierRating":4.25,"carrierRatingCount":8}
        """)
        #expect(offer.carrierRating == 4.25 && offer.carrierRatingCount == 8 && offer.carrierId == "c1")
    }
}
