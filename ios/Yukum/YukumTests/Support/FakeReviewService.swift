//
//  FakeReviewService.swift
//  YukumTests
//

import Foundation
@testable import Yukum

// ReviewServicing'in sahtesi: sunucu yok, cevabı test belirler, giden istekler kaydedilir
final class FakeReviewService: ReviewServicing {
    var createResult: Result<Void, Error> = .success(())
    private(set) var createCalls: [(offerId: String, body: CreateReviewRequest)] = []
    var profileResult: Result<CarrierProfile, Error> = .success(Sample.profile())
    private(set) var profileCalls: [String] = []

    func create(offerId: String, _ body: CreateReviewRequest) async throws { createCalls.append((offerId, body)); try createResult.get() }
    func carrierProfile(id: String) async throws -> CarrierProfile { profileCalls.append(id); return try profileResult.get() }
    var shipperProfileResult: Result<ShipperPublicProfile, Error> = .success(ShipperPublicProfile(id: "s1", fullName: "Ayşe Kaya", avatarUrl: nil, companyName: "Kaya Gıda",
        cityName: "Mersin", about: nil, memberSince: "2026-03-01T10:00:00Z", completedListingCount: 4, openListingCount: 1))
    func shipperProfile(id: String) async throws -> ShipperPublicProfile { profileCalls.append(id); return try shipperProfileResult.get() }
}
