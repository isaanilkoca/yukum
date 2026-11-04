//
//  00_Rehber_Models_Networking.swift — Models/Networking — ağın tek kapısı
//  (Bu dosyada kod yok; klasörün ilk dosyası olarak ne nerede olduğunu anlatır.)
//

// Servislerin hepsi isteği buradan gönderir. Sunucuya giden TEK yol APIClient'tır (AuthSession yenileme/çıkış için kendi isteğini atar).
// 
//
//  APIClient                    isteği kurar, jeton ekler, URLSession ile gönderir, 401'de yenileyip tekrarlar, JSON'u Model'e çevirir  ← 5 servis
//  AuthSession                  jetonlar: erişim jetonu bellekte, yenileme jetonu Keychain'de; POST /auth/refresh ve /auth/logout'u KENDİSİ atar  ← APIClient, LoginViewModel, HomeViewModel
//  APIConfig                    sunucu adresi (tek yer)
//  HTTPMethod                   GET / POST / DELETE…
//  APIError                     API'den dönen hata (Türkçe mesajla)
//  APIErrorResponse             sunucunun hata JSON'u; APIError buradan doldurulur
//  Error+UserMessage            herhangi bir hatayı ekranda gösterilecek Türkçe yazıya çevirir (error.userMessage)  ← bütün ViewModel'ler
//  Notification+SessionExpired  'oturum bitti' duyurusunun adı. AuthSession yayınlar, HomeView dinleyip girişe döner
