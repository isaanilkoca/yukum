//
//  00_Rehber_Models_Networking.swift — Models/Networking/ — SUNUCUYA TEK KAPI
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: Bütün istekler buradan geçer. Servisler (Services/) yalnız "hangi uç, hangi paket" der; gerisi burada.
//
// DOSYALAR
//  APIClient.swift          GENEL İSTEK METODU (yöneticinin istediği "her yerden dinamik kullanılan get/post/put"):
//                             send<Response>(.get/.post/.put/.delete, "/api/v1/…", query:, body:, authorized:, fallback:) → çözülmüş cevap
//                             sendNoContent(…) → cevapsız uçlar (204) · upload(…) → çok parçalı dosya (profil fotoğrafı) · data(path) → ham bayt (foto)
//                           İÇERİDE: jeton ekler (Bearer) → 401 gelirse AuthSession ile BİR KEZ yeniler → isteği tekrarlar
//                                    → hata ise sunucunun Türkçe mesajını (ProblemDetails) APIError'a koyar
//                           init(baseURL:session:auth:) — testte sahte ağ (URLProtocol) takılır
//  AuthSession.swift        actor: erişim jetonu (bellekte, 15 dk) + yenileme jetonu (Keychain, 30 gün)
//                             signIn · signOut (POST /auth/logout) · restore (açılışta otomatik giriş) · refreshAccessToken
//                             AYNI ANDA 5 istek 401 alsa bile TEK yenileme yapılır (actor + bekleyen görev paylaşımı)
//  APIConfig.swift          baseURL: simülatör → http://localhost:5054 · telefon → http://{Mac IP}:5054 (devMachineHost: ev Wi-Fi 192.168.1.18,
//                           hotspot 172.20.10.11). Canlıda https alan adı olacak.
//  APIError.swift           APIError {message, isSessionExpired, code?} — code: makine kodu (ör. "email_not_verified" → kod ekranı açılır)
//  APIErrorResponse.swift   sunucunun hata JSON'u: {detail, errors{alan:[mesaj]}, code?} — ilk alan hatası ekrana yazılır
//  Error+UserMessage.swift  error.userMessage: her hatayı Türkçe metne çevirir (iptal edilen istek → nil, ekrana yazılmaz)
//  HTTPMethod.swift         .get .post .put .delete
//  Notification+SessionExpired.swift  oturum bitti yayını → ekranlar giriş ekranına döner
//
// KULLANAN: Services/* (hepsi) · LoginViewModel (AuthSession.restore)
// KURAL: Ekran/ViewModel ASLA URLSession'a doğrudan gitmez; her istek bir Service fonksiyonu üzerinden.
