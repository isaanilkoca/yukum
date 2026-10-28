//
//  AuthService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import Foundation // Swift'in hazır ağ araçları bu kütüphanede

// API ile konuştuğumuz tek yer. [BİZİM] = adı biz koyduk | [SWIFT] = Swift'in hazır kodu

// KULLANIM: post fonksiyonu hata bulunca "throw AuthError(message:)" ile fırlatır; ekranlar (RegisterView, CarrierRegisterView) catch ile yakalayıp message'ı kırmızı yazar.
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

    // <Body: Encodable>: Body = herhangi bir paket türü | Encodable [SWIFT]: JSON'a çevrilebilir olmalı | path: oda adresi
    private func post<Body: Encodable>(_ path: String, body: Body) async throws -> RegisterResponse {

        let url = URL(string: baseURL + path)! // URL(string:) [SWIFT]: yazıyı adrese çevirir | baseURL + path: ana adres + oda | !: boş çıkmaz

        var request = URLRequest(url: url) // URLRequest [SWIFT]: adrese gidecek zarf | request: [BİZİM] zarfın adı

        request.httpMethod = "POST" // request: zarf | .httpMethod: gönderim türü | "POST": veri gönderiyorum (büyük yaz) | "GET" olsaydı veri isterdik

        request.setValue("application/json", forHTTPHeaderField: "Content-Type") // .setValue: zarfa etiket yapıştırır | "Content-Type": etiketin adı (içerik türü) | "application/json": değeri (içinde JSON var) | başka etiket: "Authorization" = giriş jetonu

        request.httpBody = try JSONEncoder().encode(body) // .httpBody: zarfın içi | JSONEncoder() [SWIFT]: struct'ı JSON'a çevirir | .encode(body): "bu paketi çevir" | try: hata çıkabilir

        let (data, response) = try await URLSession.shared.data(for: request) // URLSession [SWIFT]: postacı | .shared: hazır ortak postacı | .data(for:): zarfı gönder, cevabı getir | await: cevap gelene kadar bekle | (data, response): dönen iki şeye verdiğimiz adlar, (veri, cevap) da olabilirdi | data: cevabın içeriği (JSON) | response: durum bilgisi

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0 // as? HTTPURLResponse: HTTP cevabı olarak oku | .statusCode [SWIFT]: sunucunun notu (201 oluştu, 400 alan hatalı, 409 zaten kayıtlı, 401 yetkisiz) | ?? 0: okunamazsa 0

        if status == 201 { // 201 = hesap oluştu
            return try JSONDecoder().decode(RegisterResponse.self, from: data) // JSONDecoder() [SWIFT]: JSON'u struct'a çevirir | .decode(...): "data'yı RegisterResponse'a çevir" | .self: türün kendisi
        }

        let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) // try?: çevrilemezse hata verme, boş ver
        let firstFieldError = apiError?.errors?.values.first?.first // ?.: boş değilse devam et | errors'daki ilk alanın ilk mesajı
        throw AuthError(message: firstFieldError ?? apiError?.detail ?? "Bir hata oluştu.") // throw: hatayı fırlat | ??: soldaki boşsa sağdakine geç (alan hatası → genel mesaj → sabit yazı)
    }
}
