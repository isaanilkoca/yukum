//
//  ChatServicing.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: ChatServicing (sözleşme) ────────────────────────────────────
// │ GERÇEK    : Services/ChatService.swift | SAHTE (test): YukumTests/Support/FakeChatService.swift
// │ KULLANAN  : ViewModels/ChatViewModel
// └──────────────────────────────────────────────────────────────────────

// ⮕ KULLANIM [ChatServicing]: kullanır: ChatViewModel › service, ChatViewModel › init(), ChatService › complete(), FakeChatService (test)
protocol ChatServicing { // protocol [SWIFT]: sözleşme: "bu fonksiyonlara sahip olan her şey bu sözleşmeyi karşılar"
    // ⮕ KULLANIM [messages]: çağırır: ChatViewModel › load()
    func messages(offerId: String) async throws -> [ChatMessage] // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
    // ⮕ KULLANIM [send]: çağırır: ChatViewModel › send(), ChatView › body, ChatService › messages(), ChatViewModelTests (test)
    func send(offerId: String, _ body: SendMessageRequest) async throws
    // ⮕ KULLANIM [clear]: çağırır: ChatViewModel › clear(), ChatView › body, ChatViewModelTests (test), RegisterViewModelTests (test)
    func clear(offerId: String) async throws
    // ⮕ KULLANIM [complete]: çağırır: ChatViewModel › complete(), ChatView › body, ChatViewModelTests (test)
    func complete(offerId: String) async throws
}
