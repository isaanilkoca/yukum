//
//  FakeAuthService.swift
//  YukumTests
//

import Foundation
@testable import Yukum

final class FakeAuthService: AuthServicing {
    var loginResult: Result<LoginResponse, Error> = .failure(StubError())
    private(set) var loginBodies: [LoginRequest] = []
    func login(_ body: LoginRequest) async throws -> LoginResponse { loginBodies.append(body); return try loginResult.get() }
}
