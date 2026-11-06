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
}
