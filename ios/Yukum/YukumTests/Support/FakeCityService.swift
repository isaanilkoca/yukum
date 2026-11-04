//
//  FakeCityService.swift
//  YukumTests
//

import Foundation
@testable import Yukum

final class FakeCityService: CityServicing {
    var citiesResult: Result<[City], Error> = .success([])
    private(set) var citiesCalls = 0
    var districtsResult: Result<[District], Error> = .success([])
    private(set) var districtCalls: [Int] = []

    func cities() async throws -> [City] { citiesCalls += 1; return try citiesResult.get() }
    func districts(cityId: Int) async throws -> [District] { districtCalls.append(cityId); return try districtsResult.get() }
}
