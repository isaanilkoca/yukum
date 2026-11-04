//
//  AuthServicing.swift
//  Yukum
//

import Foundation

protocol AuthServicing {
    func login(_ body: LoginRequest) async throws -> LoginResponse
}
