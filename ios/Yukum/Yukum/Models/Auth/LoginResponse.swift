//
//  LoginResponse.swift
//  Yukum
//

import Foundation

// API'den dönen başarılı giriş cevabı (200).
// KULLANAN: AuthService.login bu pakete çevirip geri döner → Views/LoginView.swift okur (jeton + kullanıcı).
// nonisolated: actor (AuthSession) içinde de çevrilebilsin diye ana iş parçacığı bağından çıkarıldı
nonisolated struct LoginResponse: Decodable {

    let accessToken: String // giriş jetonu (15 dk geçerli); sonraki isteklerde "ben girişliyim" kanıtı → başlıkta "Authorization: Bearer <jeton>" | yalnız BELLEKTE tutulur
    // refreshToken: yenileme jetonu (30 gün) | NE İŞE YARAR: erişim jetonu bitince kullanıcı şifre yazmadan yenisini almak için | NEREDE: AuthSession Keychain'e kaydeder | TEK KULLANIMLIK: her yenilemede yenisi gelir (rotasyon)
    let refreshToken: String
    let user: LoginUser // cevaptaki "user": { ... } kutusu yukarıdaki LoginUser'a çevrilir
    // accessTokenExpiresAt / refreshTokenExpiresAt (bitiş zamanları) alanlarını almıyoruz: jeton süresi dolunca sunucu 401 verir, o zaman yeniliyoruz (reaktif yenileme)
}
// Hata cevabı (401 şifre yanlış, 423 kilit...) Yük Veren kaydındaki ile aynı: APIErrorResponse (Models/Auth/), yenisi gerekmez.
