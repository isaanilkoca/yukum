//
//  00_Rehber_Models_Chat.swift — Models/Chat/ — SOHBET PAKETLERİ
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: Teklif üzerinden yürüyen sohbetin mesaj kalıpları (sohbet = bir teklifin iki tarafı arasında).
//
//  ChatMessage.swift          ChatMessage {id, text, createdAt, isMine} ← GET /api/v1/offers/{offerId}/messages
//                             isMine: sunucu "bu mesaj senin mi" diye hesaplar → balon sağda (turuncu) / solda
//  SendMessageRequest.swift   SendMessageRequest {text}                 → POST /api/v1/offers/{offerId}/messages
//
// KULLANAN: Services/ChatService → ViewModels/ChatViewModel (birkaç saniyede bir yeni mesaj sorar) → Views/ChatView
// KURAL: Reddedilen/tamamlanan/iptal teklifte ve iki taraftan biri engellediyse yazma 409 (eski mesajlar okunur).
