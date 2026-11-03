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

    // ─── Sohbet işlemleri: ikisi de "gövdesiz" istek, tek ortak yardımcıyı kullanır (kod tekrarı olmasın) ───

    // clear: "Mesajları Temizle" | sohbetteki mesajları YALNIZ KENDİ görünümümden siler, karşı taraf görmeye devam eder
    // NE İŞE YARAR: sunucu mesajları BENİM için "gizli" işaretler (DB'den silmez) | silmeden SONRA yazılan yeni mesajlar normal görünür
    // NEREDE KULLANILIR: View/ChatView.swift → sağ üst menü "Mesajları Temizle" | API: DELETE /api/v1/offers/{offerId}/messages
    func clear(offerId: String) async throws {
        try await call(method: "DELETE", path: "/api/v1/offers/\(offerId)/messages", failMessage: "Mesajlar silinemedi.")
    }

    // complete: "İşi Bitir ve Sil" | kabul edilmiş işi tamamlar
    // NE İŞE YARAR: teklif İKİ TARAFTA "Tamamlandı" olur ve sohbet iki tarafta yazmaya kilitlenir | ama silme yalnız BENİM tarafımda: teklif geçmişimden ve mesajlarım silinir, karşı taraf Tamamlandı olarak görür ve kendi isteğiyle siler
    // NEREDE KULLANILIR: View/ChatView.swift → sağ üst menü "İşi Bitir ve Sil" (yalnız kabul edilmiş tekliflerde) | API: POST /api/v1/offers/{offerId}/complete
    func complete(offerId: String) async throws {
        try await call(method: "POST", path: "/api/v1/offers/\(offerId)/complete", failMessage: "İş tamamlanamadı.")
    }

    // call: gövdesi olmayan (veri göndermeyen), cevabında veri beklemeyen istekler için ortak fonksiyon | private: yalnız bu struct görür
    // method: HTTP yöntemi ("DELETE", "POST") | path: adresin devamı | failMessage: sunucu açıklama vermezse gösterilecek sabit hata yazısı
    private func call(method: String, path: String, failMessage: String) async throws {
        guard let token = Session.accessToken else { throw AuthError(message: "Oturum bulunamadı, tekrar giriş yapın.") } // jeton yoksa giriş yok
        var request = URLRequest(url: URL(string: baseURL + path)!) // adres | ! = bozuk çıkmaz, eminim
        request.httpMethod = method // verilen yöntemi kullan
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") // kimlik kartı | API jetondan Yük Veren mi Taşımacı mı olduğumuzu bulur, hangi tarafı etkileyeceğine buna göre karar verir
        let (data, response) = try await URLSession.shared.data(for: request) // gönder, cevabı bekle
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0 // durum kodu
        if (200...299).contains(status) { return } // başarı (200 ya da 204): döndürecek bir şey yok, fonksiyon biter
        if status == 401 || status == 403 { throw AuthError(message: "Oturum süresi doldu, tekrar giriş yapın.") }
        let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) // hata cevabını çevir | try?: çevrilemezse nil | APIErrorResponse: Network/RegisterRequest.swift
        throw AuthError(message: apiError?.detail ?? failMessage) // detail: örn. "Yalnız kabul edilmiş iş tamamlanabilir."
    }
}
