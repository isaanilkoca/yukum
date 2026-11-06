//
//  Sample.swift
//  YukumTests
//

import Foundation
@testable import Yukum

// Test verisi üretici yardımcıları (alan çokluğundan testleri okunur tutmak için)
enum Sample {
    static let shipper = LoginUser(id: "s1", displayName: "Yük Veren", role: "Shipper")
    static let carrier = LoginUser(id: "c1", displayName: "Taşımacı", role: "Carrier")

    static func listing(_ id: String = "l1", title: String = "İlan") -> Listing {
        Listing(id: id, title: title, weightKg: 1000, fromCityName: "Mersin", fromDistrictName: "Mezitli", toCityName: "İstanbul", toDistrictName: "Kadıköy",
                pickupDate: "2026-12-01", budget: 5000, myOfferAmount: nil, myOfferStatus: nil, distanceKm: nil,
                description: nil, vehicleType: "Truck", fromCityId: 33, fromDistrictId: 1, toCityId: 34, toDistrictId: 2)
    }
    // page: ilan listesini API'nin sayfa zarfına sarar | total verilmezse sayfadaki sayı kadar
    static func page(_ items: [Listing], total: Int? = nil) -> Page<Listing> {
        Page(items: items, page: 1, pageSize: ListingService.pageSize, totalCount: total ?? items.count)
    }
    static func listingOffer(_ id: String = "o1", status: String = "Pending") -> ListingOffer {
        ListingOffer(id: id, carrierName: "Taşımacı", amount: 1000, note: nil, status: status, carrierId: "c1", carrierRating: 4.5, carrierRatingCount: 2)
    }
    static func carrierOffer(_ id: String = "o1", status: String = "Pending", isNew: Bool = false, stage: String = "NotStarted") -> CarrierOffer {
        CarrierOffer(id: id, listingTitle: "İlan", fromCityName: "Mersin", toCityName: "İstanbul", amount: 1000, status: status, isNew: isNew,
                     fromDistrictName: "Mezitli", toDistrictName: "Kadıköy", shipperName: "Yük Veren", weightKg: 1000, pickupDate: "2026-12-01", listingId: "l1", note: "not", stage: stage)
    }
    static func historyOffer(_ id: String = "o1", status: String = "Accepted", stage: String = "NotStarted", reviewed: Bool = false) -> ShipperHistoryOffer {
        ShipperHistoryOffer(id: id, listingTitle: "İlan", fromCityName: "Mersin", fromDistrictName: "Mezitli", toCityName: "İstanbul", toDistrictName: "Kadıköy",
                            weightKg: 1000, pickupDate: "2026-12-01", carrierName: "Taşımacı", amount: 1000, status: status, stage: stage, carrierId: "c1", reviewed: reviewed)
    }
    static func profile(rating: Double = 4.5, count: Int = 2, reviews: [CarrierReview]? = nil) -> CarrierProfile {
        CarrierProfile(id: "c1", fullName: "Veli Nakliyat", about: nil, averageRating: rating, ratingCount: count, completedJobCount: 3,
                       reviews: reviews ?? [CarrierReview(rating: 5, comment: "Harika", shipperName: "Ali V.", listingTitle: "Mobilya", fromCityName: "Mersin", toCityName: "İstanbul", createdAt: "2026-11-07T10:00:00Z")])
    }
    static func message(_ id: String = "m1", text: String = "Merhaba", mine: Bool = true) -> ChatMessage {
        ChatMessage(id: id, text: text, createdAt: "2026-11-04T10:00:00Z", isMine: mine)
    }
}
