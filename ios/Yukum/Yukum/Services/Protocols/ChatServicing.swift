//
//  ChatServicing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: ChatServicing (sözleşme) ────────────────────────────────────
// │ GERÇEK    : Services/ChatService.swift | SAHTE (test): YukumTests/Support/FakeChatService.swift
// │ KULLANAN  : ViewModels/ChatViewModel
// └──────────────────────────────────────────────────────────────────────

protocol ChatServicing {
    func messages(offerId: String) async throws -> [ChatMessage]
    func send(offerId: String, _ body: SendMessageRequest) async throws
    func clear(offerId: String) async throws
    func complete(offerId: String) async throws
}
