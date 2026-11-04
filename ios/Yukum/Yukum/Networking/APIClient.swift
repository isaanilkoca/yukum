//
//  APIClient.swift
//  Yukum
//

import Foundation


// BU STRUCT: API'ye giden TÜM istekler buradan geçer (tek kapı). Daha önce her serviste aynı 15 satır tekrar ediyordu:
//   adres kur → zarf hazırla → jeton ekle → gönder → durum koduna bak → cevabı çevir → hata yazısı çıkar.
// Şimdi bu işleri yalnız burası yapar; servisler tek satırlık oldu (örn. ListingService.myListings).
// OTOMATİK YENİLEME: istek 401 (jeton süresi doldu) alırsa AuthSession'dan yeni jeton alınır ve istek BİR KEZ tekrarlanır. Kullanıcı bunu fark etmez.
// GENERIC: send<Response: Decodable> → dönen tür çağrıdan anlaşılır ([Listing], Int, LoginResponse...) | tek fonksiyon her cevap türünü çevirir
// BAĞLANTI: Services/*Service.swift hepsi bunu kullanır | jeton işleri: Networking/AuthSession.swift | adres: Networking/APIConfig.swift | hata türü: Networking/APIError.swift
struct APIClient {

    static let shared = APIClient() // ortak örnek | servisler bunu kullanır

    private let baseURL: String
    private let session: URLSession // dışarıdan verilebilir: testlerde sahte postacı takılır
    private let auth: AuthSession

    init(baseURL: String = APIConfig.baseURL, session: URLSession = .shared, auth: AuthSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.auth = auth
    }

    // send: istek at, cevabı Response türüne çevir
    // method: GET/POST... | path: adresin devamı | query: ?ad=değer çiftleri | body: gönderilecek paket (Encodable: JSON'a çevrilebilir)
    // authorized: true ise istekte jeton gider ve 401'de yenileme denenir | false: giriş/kayıt/il listesi gibi herkese açık uçlar
    // fallback: sunucu hata açıklaması vermezse ekranda gösterilecek sabit yazı
    func send<Response: Decodable>(_ method: HTTPMethod = .get, _ path: String, query: [URLQueryItem] = [], body: (any Encodable)? = nil,
                                   authorized: Bool = true, fallback: String = "Bir hata oluştu.") async throws -> Response {
        let data = try await perform(method, path, query: query, body: body, authorized: authorized, fallback: fallback)
        return try JSONDecoder().decode(Response.self, from: data) // JSON → Response (örn. [Listing])
    }

    // sendNoContent: cevabında veri olmayan istekler (204) | örn. silme, "görüldü" işaretleme
    func sendNoContent(_ method: HTTPMethod, _ path: String, body: (any Encodable)? = nil,
                       authorized: Bool = true, fallback: String = "Bir hata oluştu.") async throws {
        _ = try await perform(method, path, query: [], body: body, authorized: authorized, fallback: fallback)
    }

    // ─── Asıl iş ───
    private func perform(_ method: HTTPMethod, _ path: String, query: [URLQueryItem], body: (any Encodable)?,
                         authorized: Bool, fallback: String) async throws -> Data {
        // 1) Jeton hazırla. Uygulama yeni açıldıysa bellekte jeton yoktur ama Keychain'de yenileme jetonu olabilir: önce yenile.
        var token: String? = nil
        if authorized {
            token = await auth.currentAccessToken()
            if token == nil {
                guard await auth.hasStoredSession else { throw APIError(message: "Oturum bulunamadı, tekrar giriş yapın.", isSessionExpired: true) }
                token = try await auth.refreshAccessToken()
            }
        }

        // 2) İsteği at
        var (data, status) = try await execute(method, path, query: query, body: body, token: token)

        // 3) 401 = erişim jetonu süresi doldu → yenile, BİR KEZ tekrarla
        if authorized && status == 401 {
            let fresh = try await auth.tokenAfterFailure(of: token) // eşzamanlı isteklerde tek yenileme (AuthSession "tek uçuş")
            (data, status) = try await execute(method, path, query: query, body: body, token: fresh)
            if status == 401 { // yenilenen jetonla da 401: oturum gerçekten geçersiz
                await auth.expireSession()
                throw APIError(message: "Oturum süresi doldu, tekrar giriş yapın.", isSessionExpired: true)
            }
        }

        // 4) Sonuç
        if (200...299).contains(status) { return data } // başarı
        if authorized && status == 403 { throw APIError(message: "Bu işlem için yetkiniz yok.") } // giriş var ama rol uygun değil (örn. Taşımacı ilan açamaz)

        // Diğer hatalar (400, 404, 409, 423...): sunucu Türkçe açıklama gönderir (ProblemDetails) → ekrana o yazılır
        let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) // try?: çevrilemezse nil
        let firstFieldError = apiError?.errors?.values.first?.first // ilk alan hatası (örn. "Başlık boş olamaz.")
        throw APIError(message: firstFieldError ?? apiError?.detail ?? fallback) // ??: soldaki boşsa sağdakine geç
    }

    // execute: tek bir HTTP isteğini kurar ve gönderir | -> (cevap içeriği, durum kodu)
    private func execute(_ method: HTTPMethod, _ path: String, query: [URLQueryItem], body: (any Encodable)?,
                         token: String?) async throws -> (Data, Int) {
        // URLComponents [SWIFT]: adresi parça parça kurar (boşluk/Türkçe karakter kodlamasını kendisi yapar)
        var components = URLComponents(string: baseURL + path)!
        if !query.isEmpty { components.queryItems = query } // ?ad=değer&... kısmı
        var request = URLRequest(url: components.url!)
        request.httpMethod = method.rawValue
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") } // kimlik kartı | API kim olduğumuzu ve rolümüzü buradan okur
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type") // içinde JSON var
            request.httpBody = try JSONEncoder().encode(body) // paketi JSON'a çevir
        }
        let (data, response) = try await session.data(for: request) // gönder, cevabı bekle | internet yoksa burada hata fırlar
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}
