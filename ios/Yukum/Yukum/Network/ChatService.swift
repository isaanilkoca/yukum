//
//  ChatService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 2.11.2026.
//

import Foundation


// BU DOSYA: sohbet uçlarıyla konuşur. Diğer servisler gibi istekte jeton taşır.
// FONKSİYON HARİTASI: messages = mesajları ÇEKME (GET) | send = mesaj GÖNDERME (POST)
// BAĞLANTI: View/ChatView.swift çağırır | jeton: Network/Session.swift | kalıplar: Network/ChatModels.swift | API: backend MessagesController
struct ChatService { // ChatService [BİZİM] ad

    private let baseURL = "http://localhost:5054" // sunucunun ana adresi | diğer servislerle aynı (canlıda hepsi birlikte değişecek)

    // messages: bir teklifin sohbetindeki tüm mesajları getirir (eskiden yeniye)
    // NE İŞE YARAR: sohbet ekranının verisi | GET /api/v1/offers/{offerId}/messages | yalnız teklifin iki tarafı görür
    // NEREDE KULLANILIR: View/ChatView.swift → loadMessages() | ekran açılınca ve birkaç saniyede bir çağrılır (yenileme)
    func messages(offerId: String) async throws -> [ChatMessage] { // offerId: hangi teklifin sohbeti | -> [ChatMessage]: mesaj listesi
        guard let token = Session.accessToken else { throw AuthError(message: "Oturum bulunamadı, tekrar giriş yapın.") } // jeton yoksa giriş yok
        var request = URLRequest(url: URL(string: baseURL + "/api/v1/offers/\(offerId)/messages")!) // \(offerId): adrese teklif numarasını koyar | GET'te yöntem yazılmaz
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") // kimlik kartı | yazılmazsa API 401 verir
        let (data, response) = try await URLSession.shared.data(for: request) // gönder, cevabı bekle
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0 // durum kodu
        if (200...299).contains(status) { return try JSONDecoder().decode([ChatMessage].self, from: data) } // JSON → [ChatMessage]
        if status == 401 || status == 403 { throw AuthError(message: "Oturum süresi doldu, tekrar giriş yapın.") } // jeton süresi doldu
        throw AuthError(message: "Mesajlar alınamadı.") // 404: bu sohbetin tarafı değilsin
    }

    // send: sohbete mesaj yazar
    // NE İŞE YARAR: yazdığımız metni sunucuya kaydeder | POST /api/v1/offers/{offerId}/messages | reddedilmiş tekliflerde API 409 verir
    // NEREDE KULLANILIR: View/ChatView.swift → Gönder düğmesi | başarıdan sonra ekran mesajları yeniden çeker
    func send(offerId: String, _ body: SendMessageRequest) async throws { // _ body: yazılan mesaj paketi | bir şey dönmez (Void)
        guard let token = Session.accessToken else { throw AuthError(message: "Oturum bulunamadı, tekrar giriş yapın.") }
        var request = URLRequest(url: URL(string: baseURL + "/api/v1/offers/\(offerId)/messages")!)
        request.httpMethod = "POST" // veri gönderiyoruz
        request.setValue("application/json", forHTTPHeaderField: "Content-Type") // içinde JSON var
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body) // paketi JSON'a çevirip zarfa koy → {"text":"..."}
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if (200...299).contains(status) { return } // başarıda 201 gelir, döndürecek bir şey yok, fonksiyon biter
        if status == 401 || status == 403 { throw AuthError(message: "Oturum süresi doldu, tekrar giriş yapın.") }
        let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) // hata cevabını çevir | APIErrorResponse: Network/RegisterRequest.swift
        let firstFieldError = apiError?.errors?.values.first?.first // ilk alan hatası (örn. "Mesaj boş olamaz.")
        throw AuthError(message: firstFieldError ?? apiError?.detail ?? "Mesaj gönderilemedi.") // detail: örn. "Reddedilen teklifte sohbet kapalı."
    }
}
