//
//  LoginRole.swift
//  Yukum
//

import Foundation

// Giriş ekranındaki hesap türü seçeneği | aynı e-posta/telefon hem Yük Veren hem Taşımacı olarak kayıtlı olabilir (K-022), hangisine girileceğini kullanıcı seçer
// enum [SWIFT]: sabit seçenek listesi | String: rawValue = API'nin beklediği yazı ("Shipper"/"Carrier") → LoginRequest.role
// CaseIterable [SWIFT]: allCases ile Picker'ı doldururuz | Identifiable [SWIFT]: ForEach'te id: yazmak gerekmez
// BAĞLANTI: Views/LoginView (Picker) ↔ ViewModels/LoginViewModel.role → Models/Auth/LoginRequest.role → POST /api/v1/auth/login
enum LoginRole: String, CaseIterable, Identifiable {
    case shipper = "Shipper"
    case carrier = "Carrier"

    var id: String { rawValue }

    // title: seçicide görünen Türkçe ad
    var title: String {
        switch self {
        case .shipper: "Yük Veren"
        case .carrier: "Taşımacı"
        }
    }
}
