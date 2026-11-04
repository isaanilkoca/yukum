//
//  ChatServicing.swift
//  Yukum
//

import Foundation

protocol ChatServicing {
    func messages(offerId: String) async throws -> [ChatMessage]
    func send(offerId: String, _ body: SendMessageRequest) async throws
    func clear(offerId: String) async throws
    func complete(offerId: String) async throws
}
