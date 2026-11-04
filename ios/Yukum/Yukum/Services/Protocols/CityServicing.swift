//
//  CityServicing.swift
//  Yukum
//

import Foundation

protocol CityServicing {
    func cities() async throws -> [City]
    func districts(cityId: Int) async throws -> [District]
}
