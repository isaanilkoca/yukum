//
//  ChatServicing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: ChatServicing (sözleşme) ────────────────────────────────────
// │ GERÇEK    : Services/ChatService.swift | SAHTE (test): YukumTests/Support/FakeChatService.swift
// │ KULLANAN  : ViewModels/ChatViewModel
// │ HAZIR (Swift/Apple) [SWIFT] : async, throws, protocol, String
// │ BİZİM (bizim yazdığımız) [BİZİM] : türler: ChatServicing | fonksiyonlar: messages, send, clear, complete
// └──────────────────────────────────────────────────────────────────────

protocol ChatServicing { // protocol [SWIFT]: sözleşme: "bu fonksiyonlara sahip olan her şey bu sözleşmeyi karşılar"
    func messages(offerId: String) async throws -> [ChatMessage] // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
    func send(offerId: String, _ body: SendMessageRequest) async throws
    func clear(offerId: String) async throws
    func complete(offerId: String) async throws
}
