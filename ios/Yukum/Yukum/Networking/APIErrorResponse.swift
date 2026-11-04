//
//  APIErrorResponse.swift
//  Yukum
//

import Foundation

// API hata verince (400, 409...) gelen cevabın kalıbı; ekranda göstereceğimiz mesajı buradan okuruz.
// KULLANAN: AuthService.post, hata cevabını buna çevirip mesajı APIError içine koyar; ekran o mesajı gösterir.
nonisolated struct APIErrorResponse : Decodable {

    let detail : String?              // genel Türkçe mesaj (örn. "Bu e-posta zaten kayıtlı")
    let errors: [String: [String]]?   // alan adı → o alanın hata mesajları (örn. "password": ["Şifre en az 8 karakter olmalı"])
}

// ÖZET:
// - Gönderirken: struct → JSON (Encodable)
// - Cevap gelirken: JSON → struct (Decodable)
// - Hata gelirse: mesaj APIErrorResponse içinden okunup ekranda gösterilir

// MARK: - Taşımacı kaydı (POST /api/v1/auth/register/carrier)
