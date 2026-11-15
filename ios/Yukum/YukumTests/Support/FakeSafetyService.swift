//
//  FakeSafetyService.swift
//  YukumTests
//

import Foundation
@testable import Yukum

// SafetyServicing'in sahtesi (15 Kasım): engel listesi bellekte tutulur, giden istekler kaydedilir
final class FakeSafetyService: SafetyServicing {
    var blockedList: [BlockedUser] = []
    var failNext = false // true → sıradaki istek hata verir
    private(set) var blockCalls: [String] = []
    private(set) var unblockCalls: [String] = []
    private(set) var reportCalls: [(userId: String, body: ReportUserRequest)] = []

    private func maybeFail() throws { if failNext { failNext = false; throw StubError() } }

    func block(userId: String) async throws { try maybeFail(); blockCalls.append(userId) }
    func unblock(userId: String) async throws { try maybeFail(); unblockCalls.append(userId) }
    func blocked() async throws -> [BlockedUser] { try maybeFail(); return blockedList }
    func report(userId: String, _ body: ReportUserRequest) async throws { try maybeFail(); reportCalls.append((userId, body)) }
}
