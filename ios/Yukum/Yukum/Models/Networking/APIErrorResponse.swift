//
//  APIErrorResponse.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: APIErrorResponse (sunucunun hata JSON'u) ────────────────────
// │ NE        : Sunucu hata verince gönderdiği JSON (ProblemDetails): detail = genel mesaj, errors = alan alan hatalar
// │ KULLANAN  : Models/Networking/APIClient.perform → hata mesajını çıkarıp APIError'a koyar (örn. "Başlık boş olamaz.")
// └──────────────────────────────────────────────────────────────────────

// API hata verince (400, 409...) gelen cevabın kalıbı; ekranda göstereceğimiz mesajı buradan okuruz.
// KULLANAN: AuthService.post, hata cevabını buna çevirip mesajı APIError içine koyar; ekran o mesajı gösterir.
// ⮕ KULLANIM [APIErrorResponse]: kullanır: APIClient › perform()
nonisolated struct APIErrorResponse : Decodable { // Decodable [SWIFT]: JSON'dan bu türde değer üretilebilir

    // ⮕ KULLANIM [detail]: okur: APIClient › perform()
    let detail : String?              // genel Türkçe mesaj (örn. "Bu e-posta zaten kayıtlı")
    // ⮕ KULLANIM [errors]: okur: APIClient › perform()
    let errors: [String: [String]]?   // alan adı → o alanın hata mesajları (örn. "password": ["Şifre en az 8 karakter olmalı"])
}

// ÖZET:
// - Gönderirken: struct → JSON (Encodable)
// - Cevap gelirken: JSON → struct (Decodable)
// - Hata gelirse: mesaj APIErrorResponse içinden okunup ekranda gösterilir

// MARK: - Taşımacı kaydı (POST /api/v1/auth/register/carrier)
