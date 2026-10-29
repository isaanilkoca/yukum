//
//  AuthService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import Foundation // Swift'in hazır ağ araçları bu kütüphanede

// API ile konuştuğumuz tek yer. [BİZİM] = adı biz koyduk | [SWIFT] = Swift'in hazır kodu

// KULLANIM: post fonksiyonu hata bulunca "throw AuthError(message:)" ile fırlatır; ekranlar (RegisterView, CarrierRegisterView, LoginView) catch ile yakalayıp message'ı kırmızı yazar.
struct AuthError: Error { // Error [SWIFT]: fırlatılabilir hata
    let message: String // ekranda göstereceğimiz yazı
}

struct AuthService {

    private let baseURL = "http://localhost:5054" // sunucunun ana adresi | localhost: simülatörde Mac'imiz | 5054: API'nin portu

    // register: [BİZİM] ad | _ body: dolu form kağıdı | async: cevabı bekler, ekran donmaz | throws: hata fırlatabilir | -> RegisterResponse: başarılıysa bu döner
    // ÇAĞIRAN: View/RegisterView.swift (Yük Veren ekranı) → AuthService().register(body)
    // body'nin kalıbı: Network/RegisterRequest.swift → struct RegisterRequest
     func register(_ body: RegisterRequest) async throws -> RegisterResponse {
        try await post("/api/v1/auth/register/shipper", body: body) // "/api/..." = path: sunucudaki oda (Yük Veren kaydı)
    }

    // ÇAĞIRAN: View/CarrierRegisterView.swift (Taşımacı ekranı) → AuthService().registerCarrier(body)
    // body'nin kalıbı: Network/RegisterRequest.swift → struct RegisterCarrierRequest (içinde VehicleRequest listesi var)
    func registerCarrier(_ body: RegisterCarrierRequest) async throws -> RegisterResponse {
        try await post("/api/v1/auth/register/carrier", body: body) // aynısı, Taşımacı odası
    }

    // login: giriş yapar | -> LoginResponse: başarılıysa jeton + kullanıcı bilgisi döner
    // ÇAĞIRAN: View/LoginView.swift → AuthService().login(body) | body'nin kalıbı ve cevabın kalıbı: Network/LoginRequest.swift
    func login(_ body: LoginRequest) async throws -> LoginResponse {
        try await post("/api/v1/auth/login", body: body) // aynı post fonksiyonu; sadece oda (path) ve cevap türü (LoginResponse) farklı
    }

    // <Body: Encodable, Response: Decodable>: iki "boşluk" var, çağrıda Swift doldurur
    //   Body = gönderilen paket türü, JSON'a çevrilebilir olmalı (Encodable [SWIFT]) | path: oda adresi
    //   Response = dönen cevabın türü, JSON'dan üretilebilir olmalı (Decodable [SWIFT]) → RegisterResponse ya da LoginResponse; hangisi olacağını fonksiyonun "-> ..." satırı belirler
    private func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {

        let url = URL(string: baseURL + path)! // URL(string:) [SWIFT]: yazıyı adrese çevirir | baseURL + path: ana adres + oda | b !: boş çıkmaz

        var request = URLRequest(url: url) // URLRequest [SWIFT]: adrese gidecek zarf | request: [BİZİM] zarfın adı

        request.httpMethod = "POST" // request: zarf | .httpMethod: gönderim türü | "POST": veri gönderiyorum (büyük yaz) | "GET" olsaydı veri isterdik

        request.setValue("application/json", forHTTPHeaderField: "Content-Type") // .setValue: zarfa etiket yapıştırır | "Content-Type": etiketin adı (içerik türü) | "application/json": değeri (içinde JSON var) | başka etiket: "Authorization" = giriş jetonu

        request.httpBody = try JSONEncoder().encode(body) // .httpBody: zarfın içi | JSONEncoder() [SWIFT]: struct'ı JSON'a çevirir | .encode(body): "bu paketi çevir" | try: hata çıkabilir

        let (data, response) = try await URLSession.shared.data(for: request) // URLSession [SWIFT]: postacı | .shared: hazır ortak postacı | .data(for:): zarfı gönder, cevabı getir | await: cevap gelene kadar bekle | (data, response): dönen iki şeye verdiğimiz adlar, (veri, cevap) da olabilirdi | data: cevabın içeriği (JSON) | response: durum bilgisi

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0 // as? HTTPURLResponse: HTTP cevabı olarak oku | .statusCode [SWIFT]: sunucunun notu (201 oluştu, 400 alan hatalı, 409 zaten kayıtlı, 401 yetkisiz) | ?? 0: okunamazsa 0

        if (200...299).contains(status) { // 200...299 = başarı aralığı | 201: hesap oluştu (kayıt), 200: giriş tamam
            return try JSONDecoder().decode(Response.self, from: data) // JSONDecoder() [SWIFT]: JSON'u struct'a çevirir | .decode(...): "data'yı Response türüne çevir" | .self: türün kendisi
        }

        let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) // try?: çevrilemezse hata verme, boş ver
        let firstFieldError = apiError?.errors?.values.first?.first // ?.: boş değilse devam et | errors'daki ilk alanın ilk mesajı
        throw AuthError(message: firstFieldError ?? apiError?.detail ?? "Bir hata oluştu.") // throw: hatayı fırlat | ??: soldaki boşsa sağdakine geç (alan hatası → genel mesaj → sabit yazı)
    }
}
