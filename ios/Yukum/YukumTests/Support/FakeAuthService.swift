//
//  FakeAuthService.swift
//  YukumTests
//

import Foundation
@testable import Yukum

final class FakeAuthService: AuthServicing {
    var registerResult: Result<RegisterResponse, Error> = .success(RegisterResponse(id: "1", fullName: "Ali", email: "a@x.com", userType: "Shipper"))
    private(set) var registerBodies: [RegisterRequest] = []
    var registerCarrierResult: Result<RegisterResponse, Error> = .success(RegisterResponse(id: "2", fullName: "Veli", email: "v@x.com", userType: "Carrier"))
    private(set) var registerCarrierBodies: [RegisterCarrierRequest] = []
    var loginResult: Result<LoginResponse, Error> = .failure(StubError())
    private(set) var loginBodies: [LoginRequest] = []
    func register(_ body: RegisterRequest) async throws -> RegisterResponse { registerBodies.append(body); return try registerResult.get() }
    func registerCarrier(_ body: RegisterCarrierRequest) async throws -> RegisterResponse { registerCarrierBodies.append(body); return try registerCarrierResult.get() }
    func login(_ body: LoginRequest) async throws -> LoginResponse { loginBodies.append(body); return try loginResult.get() }

    // 15 Kasım: doğrulama + şifremi unuttum
    var verifyResult: Result<Void, Error> = .success(())
    var resetResult: Result<Void, Error> = .success(())
    private(set) var sentCodes: [CodeRequest] = []
    private(set) var verifyBodies: [VerifyEmailRequest] = []
    private(set) var forgotBodies: [CodeRequest] = []
    private(set) var resetBodies: [ResetPasswordRequest] = []
    func sendVerificationCode(_ body: CodeRequest) async throws { sentCodes.append(body) }
    func verifyEmail(_ body: VerifyEmailRequest) async throws { verifyBodies.append(body); try verifyResult.get() }
    func forgotPassword(_ body: CodeRequest) async throws { forgotBodies.append(body) }
    func resetPassword(_ body: ResetPasswordRequest) async throws { resetBodies.append(body); try resetResult.get() }
}
