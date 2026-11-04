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
                pickupDate: "2026-12-01", budget: 5000, myOfferAmount: nil, myOfferStatus: nil, distanceKm: nil)
    }
    static func listingOffer(_ id: String = "o1", status: String = "Pending") -> ListingOffer {
        ListingOffer(id: id, carrierName: "Taşımacı", amount: 1000, note: nil, status: status)
    }
    static func carrierOffer(_ id: String = "o1", status: String = "Pending", isNew: Bool = false) -> CarrierOffer {
        CarrierOffer(id: id, listingTitle: "İlan", fromCityName: "Mersin", toCityName: "İstanbul", amount: 1000, status: status, isNew: isNew,
                     fromDistrictName: "Mezitli", toDistrictName: "Kadıköy", shipperName: "Yük Veren", weightKg: 1000, pickupDate: "2026-12-01")
    }
    static func historyOffer(_ id: String = "o1", status: String = "Accepted") -> ShipperHistoryOffer {
        ShipperHistoryOffer(id: id, listingTitle: "İlan", fromCityName: "Mersin", fromDistrictName: "Mezitli", toCityName: "İstanbul", toDistrictName: "Kadıköy",
                            weightKg: 1000, pickupDate: "2026-12-01", carrierName: "Taşımacı", amount: 1000, status: status)
    }
    static func message(_ id: String = "m1", text: String = "Merhaba", mine: Bool = true) -> ChatMessage {
        ChatMessage(id: id, text: text, createdAt: "2026-11-04T10:00:00Z", isMine: mine)
    }
}
