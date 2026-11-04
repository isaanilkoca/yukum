//
//  FakeChatService.swift
//  YukumTests
//

import Foundation
@testable import Yukum

final class FakeChatService: ChatServicing {
    var messagesResult: Result<[ChatMessage], Error> = .success([])
    private(set) var messageLoads = 0
    var sendResult: Result<Void, Error> = .success(())
    private(set) var sent: [String] = []
    var clearResult: Result<Void, Error> = .success(())
    private(set) var clearCalls = 0
    var completeResult: Result<Void, Error> = .success(())
    private(set) var completeCalls = 0

    func messages(offerId: String) async throws -> [ChatMessage] { messageLoads += 1; return try messagesResult.get() }
    func send(offerId: String, _ body: SendMessageRequest) async throws { sent.append(body.text); try sendResult.get() }
    func clear(offerId: String) async throws { clearCalls += 1; try clearResult.get() }
    func complete(offerId: String) async throws { completeCalls += 1; try completeResult.get() }
}
