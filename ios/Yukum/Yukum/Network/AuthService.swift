//
//  AuthService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import Foundation // URL, URLSession, JSONEncoder gibi ağ araçları bu kütüphanede

struct AuthError: Error { // Error olunca fırlatılabilir (throw) bir hata olur
    
    let message: String  // ekranda göstereceğimiz hata mesajını taşır
}

struct AuthService {  // kayıt/giriş API çağrılarını toplayan sınıf; ekranlar ağ kodu yazmaz
    
    private let baseURL = "http://localhost:5054" // API adresi  simülatörde Mac'imiz
    
    func register (_ body: RegisterRequest) async throws -> RegisterResponse {
        // _ body: çağırırken ismi yazmadan register(istek) dersin
               // async: ağ cevabını bekler, ekran donmaz | throws: hata fırlatabilir
               // -> RegisterResponse: başarılı olursa bu paketi döner
        
        // adres + istek hazırlığı
        
        let url = URL(string: baseURL + "/api/v1/auth/register/shipper")!  // tam adres; ! = "boş olamaz" (adresi biz yazdık)
        
        var request = URLRequest(url : url) // gönderilecek mektubun zarfı; içini dolduracağımız için var
        
        request.httpMethod = "POST" // veri gönderiyoruz // POST = "veri gönderiyorum" (GET = "veri istiyorum")
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type") // "JSON yolluyorum" etiketi  // zarfa "içinde JSON var" etiketi; yoksa API anlamaz
        
        request.httpBody = try JSONEncoder().encode(body) // struct → JSON // mektubun içi: struct → JSON (Encoder = struct'tan JSON üretir)
        
        let (data, response) = try await URLSession.shared.data(for: request)   // zarfı postaya ver, cevabı bekle
              // data: cevabın içeriği (JSON) | response: durum bilgisi
        
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0   // durum kodu (201, 400, 409...); okunamazsa 0
              // as?: HTTP cevabıysa o türe çevir, değilse boş bırak | ?? 0: boşsa 0 kullan
        
        if status == 201 { // 201 hesap olusturuldu
            
            return try JSONDecoder().decode(RegisterResponse.self, from: data) // Decoder = JSON → struct
            
        }
        
        // buraya geldiysek kayıt başarısız; API'nin Türkçe mesajını bulalım
        let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) // try? = çevrilemezse hata fırlatma, boş ver
        
        let firstFieldError = apiError?.errors?.values.first?.first   // ilk alanın ilk hata mesajı (örn. "Şifre en az 8 karakter olmalı")
        
        throw AuthError(message: firstFieldError ?? apiError?.detail ?? "Bir hata oluştu.")
            // ?? zinciri: önce alan hatası, yoksa genel mesaj, o da yoksa sabit yazı
    }
    
    
}

