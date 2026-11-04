//
//  FakeSession.swift
//  YukumTests
//

import Foundation
@testable import Yukum

final class FakeSession: SessionRestoring {
    var result: Result<LoginUser?, Error> = .success(nil)
    private(set) var restoreCalls = 0
    func restore() async throws -> LoginUser? { restoreCalls += 1; return try result.get() }
}
