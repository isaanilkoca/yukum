//
//  AuthService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import Foundation // Swift'in hazır ağ araçları bu kütüphanede

// BU DOSYA: kayıt ve giriş uçlarıyla konuşur. [BİZİM] = adı biz koyduk | [SWIFT] = Swift'in hazır kodu
// İSTEĞİN KENDİSİ (adres kurma, zarf, gönderme, hata çevirme) artık Networking/APIClient.swift'te; burada yalnız "hangi adrese, hangi paketle" yazılır.
// Bu uçlar HERKESE AÇIKTIR (henüz giriş yapılmadı): authorized: false → istekte jeton gitmez, 401 yenileme denenmez.


struct AuthService {

    private let api = APIClient.shared // tüm istekler bu kapıdan geçer

    // register: Yük Veren kaydı | _ body: dolu form kağıdı | async: cevabı bekler | throws: hata fırlatabilir | -> RegisterResponse: başarılıysa bu döner
    // ÇAĞIRAN: Views/RegisterView.swift → AuthService().register(body) | body'nin kalıbı: Models/Auth/ → struct RegisterRequest
    func register(_ body: RegisterRequest) async throws -> RegisterResponse {
        try await api.send(.post, "/api/v1/auth/register/shipper", body: body, authorized: false) // "/api/..." = sunucudaki oda | authorized: false → jeton yok
    }

    // ÇAĞIRAN: Views/CarrierRegisterView.swift (Taşımacı ekranı) → AuthService().registerCarrier(body)
    // body'nin kalıbı: Models/Auth/ → struct RegisterCarrierRequest (içinde VehicleRequest listesi var)
    func registerCarrier(_ body: RegisterCarrierRequest) async throws -> RegisterResponse {
        try await api.send(.post, "/api/v1/auth/register/carrier", body: body, authorized: false) // aynısı, Taşımacı odası
    }

    // login: giriş yapar | -> LoginResponse: başarılıysa jetonlar + kullanıcı bilgisi döner
    // ÇAĞIRAN: Views/LoginView.swift → AuthService().login(body) | kalıplar: Models/Auth/
    // GİRİŞ BAŞARILI OLUNCA jetonlar burada AuthSession'a verilir: erişim jetonu belleğe, yenileme jetonu Keychain'e (ekranlar jeton yönetmek zorunda kalmaz)
    func login(_ body: LoginRequest) async throws -> LoginResponse {
        let response: LoginResponse = try await api.send(.post, "/api/v1/auth/login", body: body, authorized: false) // 401 burada "şifre yanlış" demek; yenileme denenmez
        await AuthSession.shared.signIn(response) // jetonları sakla | actor'a erişim "await" ister
        return response
    }
}

// AuthService, kendi sözleşmesini karşılar (Services/Protocols/): ViewModel'ler somut sınıfa değil sözleşmeye bağlıdır, testte sahtesi verilir
extension AuthService: AuthServicing {}
