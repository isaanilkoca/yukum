//
//  APIClient.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: APIClient (ağın tek kapısı) ─────────────────────────────────
// │ ÇAĞIRAN   : Services/*Service.swift — hepsi api.send(...) / api.sendNoContent(...) der (ViewModel'ler servis üzerinden buraya gelir)
// │ AKIŞ      : send → perform (jeton hazırla) → execute (URLSession ile gönder) → durum kodu → JSONDecoder → Model
// │ 401       : Jeton süresi dolduysa: AuthSession.tokenAfterFailure yeni jeton verir → istek BİR KEZ tekrarlanır
// │ HATA      : APIError fırlatır (mesaj: APIErrorResponse'tan) → ViewModel'in catch'i → Error.userMessage → ekranda kırmızı yazı
// │ KULLANIR  : Models/Networking/APIConfig (adres), AuthSession (jeton), HTTPMethod (GET/POST...), APIErrorResponse (hata JSON'u)
// └──────────────────────────────────────────────────────────────────────


// BU STRUCT: API'ye giden TÜM istekler buradan geçer (tek kapı). Daha önce her serviste aynı 15 satır tekrar ediyordu:
//   adres kur → zarf hazırla → jeton ekle → gönder → durum koduna bak → cevabı çevir → hata yazısı çıkar.
// Şimdi bu işleri yalnız burası yapar; servisler tek satırlık oldu (örn. ListingService.myListings).
// OTOMATİK YENİLEME: istek 401 (jeton süresi doldu) alırsa AuthSession'dan yeni jeton alınır ve istek BİR KEZ tekrarlanır. Kullanıcı bunu fark etmez.
// GENERIC: send<Response: Decodable> → dönen tür çağrıdan anlaşılır ([Listing], Int, LoginResponse...) | tek fonksiyon her cevap türünü çevirir
// BAĞLANTI: Services/*Service.swift hepsi bunu kullanır | jeton işleri: Models/Networking/AuthSession.swift | adres: Models/Networking/APIConfig.swift | hata türü: Models/Networking/APIError.swift
// ⮕ KULLANIM [APIClient]: kullanır: AuthService › api, ChatService › api, CityService › api, ListingService › api, OfferService › api, AuthSessionTests (test)
struct APIClient {

    // ⮕ KULLANIM [shared]: okur: AuthService › api, ChatService › api, CityService › api, ListingService › api, OfferService › api
    static let shared = APIClient() // ortak örnek | servisler bunu kullanır | static [SWIFT]: türün kendisine ait (örnek üretmeden erişilir)

    // ⮕ KULLANIM [baseURL]: okur: APIClient › execute()
    private let baseURL: String
    // ⮕ KULLANIM [session]: okur: APIClient › execute()
    private let session: URLSession // dışarıdan verilebilir: testlerde sahte postacı takılır | URLSession [SWIFT]: internet isteklerini gönderen postacı
    // ⮕ KULLANIM [auth]: okur: APIClient › perform()
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
    // ⮕ KULLANIM [send]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    func send<Response: Decodable>(_ method: HTTPMethod = .get, _ path: String, query: [URLQueryItem] = [], body: (any Encodable)? = nil, // Decodable [SWIFT]: JSON'dan bu türde değer üretilebilir | Encodable [SWIFT]: bu türdeki değer JSON'a çevrilebilir | URLQueryItem [SWIFT]: adreste ?ad=değer çifti
                                   authorized: Bool = true, fallback: String = "Bir hata oluştu.") async throws -> Response { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
        let data = try await perform(method, path, query: query, payload: body.map { Payload.json($0) }, authorized: authorized, fallback: fallback) // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
        return try JSONDecoder().decode(Response.self, from: data) // JSON → Response (örn. [Listing]) | JSONDecoder [SWIFT]: JSON'u struct'a çevirir | .decode [SWIFT]: JSON'dan Swift nesnesine çevirir
    }

    // sendNoContent: cevabında veri olmayan istekler (204) | örn. silme, "görüldü" işaretleme
    // ⮕ KULLANIM [sendNoContent]: çağırır: ChatService › send(), ChatService › clear(), ChatService › complete(), ListingService › cancel(), OfferService › decide(), OfferService › markSeen() … +1
    func sendNoContent(_ method: HTTPMethod, _ path: String, body: (any Encodable)? = nil,
                       authorized: Bool = true, fallback: String = "Bir hata oluştu.") async throws {
        _ = try await perform(method, path, query: [], payload: body.map { Payload.json($0) }, authorized: authorized, fallback: fallback)
    }

    // ─── 15 Kasım: Hesap Bilgilerim / profil fotoğrafı için iki ek yetenek (jeton + 401 yenileme + hata çevirme AYNI yoldan geçer) ───

    // Payload [BİZİM]: isteğin gövdesi ya JSON (çoğu uç) ya da hazır baytlar + türü (fotoğraf yükleme: multipart/form-data)
    // enum + ilişkili değer [SWIFT]: her durum kendi verisini taşır (.json(paket) / .raw(baytlar, tür))
    enum Payload {
        case json(any Encodable)
        case raw(Data, contentType: String)
    }

    // upload: tek dosyayı multipart/form-data ile gönderir, JSON cevabı Response'a çevirir
    // ÇAĞIRAN: AccountService.uploadAvatar → POST /api/v1/account/avatar (sunucu "file" alanını okur: AccountController.UploadAvatar)
    // multipart [HTTP]: gövde "sınır" (boundary) yazısıyla parçalara bölünür; her parçanın kendi başlığı (ad, dosya adı, tür) olur
    func upload<Response: Decodable>(_ path: String, field: String, fileName: String, mimeType: String, data file: Data,
                                     fallback: String = "Bir hata oluştu.") async throws -> Response {
        let boundary = "Yukum-\(UUID().uuidString)" // gövdede geçmeyecek benzersiz ayraç
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(fileName)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(file)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8)) // kapanış ayracı: sonunda "--"
        let data = try await perform(.post, path, query: [], payload: .raw(body, contentType: "multipart/form-data; boundary=\(boundary)"),
                                     authorized: true, fallback: fallback)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    // data: cevabı ÇEVİRMEDEN ham bayt olarak döner (resim) | ÇAĞIRAN: Design/AvatarView → GET /api/v1/avatars/{id}
    // NEDEN AsyncImage değil: AsyncImage [SWIFT] isteğe Authorization başlığı ekleyemez; fotoğraf ucu [Authorize] (jetonsuz 401)
    func data(_ path: String, fallback: String = "Bir hata oluştu.") async throws -> Data {
        try await perform(.get, path, query: [], payload: nil, authorized: true, fallback: fallback)
    }

    // ─── Asıl iş ───
    // ⮕ KULLANIM [perform]: çağırır: APIClient › send(), APIClient › sendNoContent()
    private func perform(_ method: HTTPMethod, _ path: String, query: [URLQueryItem], payload: Payload?,
                         authorized: Bool, fallback: String) async throws -> Data { // Data [SWIFT]: ham bayt dizisi
        // 1) Jeton hazırla. Uygulama yeni açıldıysa bellekte jeton yoktur ama Keychain'de yenileme jetonu olabilir: önce yenile.
        var token: String? = nil
        if authorized {
            token = await auth.currentAccessToken()
            if token == nil {
                guard await auth.hasStoredSession else { throw APIError(message: "Oturum bulunamadı, tekrar giriş yapın.", isSessionExpired: true) } // guard [SWIFT]: şart sağlanmazsa fonksiyondan erken çık
                token = try await auth.refreshAccessToken()
            }
        }

        // 2) İsteği at
        var (data, status) = try await execute(method, path, query: query, payload: payload, token: token)

        // 3) 401 = erişim jetonu süresi doldu → yenile, BİR KEZ tekrarla
        if authorized && status == 401 {
            let fresh = try await auth.tokenAfterFailure(of: token) // eşzamanlı isteklerde tek yenileme (AuthSession "tek uçuş")
            (data, status) = try await execute(method, path, query: query, payload: payload, token: fresh)
            if status == 401 { // yenilenen jetonla da 401: oturum gerçekten geçersiz
                await auth.expireSession()
                throw APIError(message: "Oturum süresi doldu, tekrar giriş yapın.", isSessionExpired: true)
            }
        }

        // 4) Sonuç
        if (200...299).contains(status) { return data } // başarı | .contains [SWIFT]: içinde var mı diye bakar
        if authorized && status == 403 { throw APIError(message: "Bu işlem için yetkiniz yok.") } // giriş var ama rol uygun değil (örn. Taşımacı ilan açamaz)

        // Diğer hatalar (400, 404, 409, 423...): sunucu Türkçe açıklama gönderir (ProblemDetails) → ekrana o yazılır
        let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) // try?: çevrilemezse nil | try? [SWIFT]: hata olursa çökme, nil ver
        let firstFieldError = apiError?.errors?.values.first?.first // ilk alan hatası (örn. "Başlık boş olamaz.")
        throw APIError(message: firstFieldError ?? apiError?.detail ?? fallback, code: apiError?.code) // ??: soldaki boşsa sağdakine geç | code: makine kodu (15 Kasım)
    }

    // execute: tek bir HTTP isteğini kurar ve gönderir | -> (cevap içeriği, durum kodu)
    // ⮕ KULLANIM [execute]: çağırır: APIClient › perform()
    private func execute(_ method: HTTPMethod, _ path: String, query: [URLQueryItem], payload: Payload?,
                         token: String?) async throws -> (Data, Int) {
        // URLComponents [SWIFT]: adresi parça parça kurar (boşluk/Türkçe karakter kodlamasını kendisi yapar)
        var components = URLComponents(string: baseURL + path)!
        if !query.isEmpty { components.queryItems = query } // ?ad=değer&... kısmı
        var request = URLRequest(url: components.url!) // URLRequest [SWIFT]: gidecek istek zarfı (adres, yöntem, başlıklar, gövde)
        request.httpMethod = method.rawValue
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") } // kimlik kartı | API kim olduğumuzu ve rolümüzü buradan okur
        switch payload {
        case .json(let body)?:
            request.setValue("application/json", forHTTPHeaderField: "Content-Type") // içinde JSON var
            request.httpBody = try JSONEncoder().encode(body) // paketi JSON'a çevir | JSONEncoder [SWIFT]: struct'ı JSON'a çevirir | .encode [SWIFT]: Swift nesnesinden JSON'a çevirir
        case .raw(let data, let contentType)?:
            request.setValue(contentType, forHTTPHeaderField: "Content-Type") // örn. multipart/form-data; boundary=...
            request.httpBody = data
        case nil: break // gövdesiz istek (GET, DELETE)
        }
        let (data, response) = try await session.data(for: request) // gönder, cevabı bekle | internet yoksa burada hata fırlar
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0) // HTTPURLResponse [SWIFT]: sunucunun cevap bilgisi (durum kodu dahil)
    }
}
