//
//  FakeSession.swift
//  YukumTests
//

import Foundation
@testable import Yukum

final class FakeSession: SessionRestoring, SessionSigningOut {
    var result: Result<LoginUser?, Error> = .success(nil)
    private(set) var restoreCalls = 0
    func restore() async throws -> LoginUser? { restoreCalls += 1; return try result.get() }
    private(set) var signOutCalls = 0
    func signOut() async { signOutCalls += 1 }
}
