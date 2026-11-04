//
//  AuthSession.swift
//  Yukum
//

import Foundation

// "Oturum süresi doldu, yeniden giriş gerekiyor" haberi | HomeView dinler ve giriş ekranına döner
extension Notification.Name {
    nonisolated static let sessionExpired = Notification.Name("yukum.sessionExpired") // NotificationCenter [SWIFT]: uygulama içi anons panosu | biri "yayınlar", ilgilenen ekranlar "dinler"
}

// BU SINIF: oturumun TEK sahibi. İki jetonu yönetir ve süresi dolunca otomatik yeniler.
//   erişim jetonu (accessToken)   : 15 dk, her istekte gider, yalnız BELLEKTE durur (diske yazılmaz)
//   yenileme jetonu (refreshToken): 30 gün, yalnız jeton yenilemek için kullanılır, KEYCHAIN'de durur (Security/KeychainStore.swift)
// NEDEN actor: aynı anda birçok istek 401 alabilir (liste + rozet + ...). actor, içindeki değişkenlere AYNI ANDA yalnız bir iş erişsin diye garanti eder.
//   Yenileme jetonu TEK KULLANIMLIK (sunucu rotasyon yapar): iki istek aynı jetonla ayrı ayrı yenileme yapsaydı ikincisi "çalıntı" sayılır ve oturum düşerdi.
//   Çözüm "tek uçuş" (single-flight): ilk istek yenilemeyi başlatır, diğerleri AYNI yenilemenin bitmesini bekler.
// BAĞLANTI: Network/APIClient.swift (her istekte jeton ister, 401'de yenileme ister) | Network/AuthService.swift (girişte signIn) | View/LoginView.swift (açılışta restore) | View/HomeView.swift (çıkışta signOut)
actor AuthSession { // actor [SWIFT]: kendi verisini kendi koruyan sınıf | adı [BİZİM]

    static let shared = AuthSession() // uygulamanın tek oturumu | testlerde kendi örneğimizi oluştururuz (aşağıdaki init)

    private let baseURL: String
    private let session: URLSession // URLSession [SWIFT]: postacı | dışarıdan verilebilir ki testlerde sahte postacı takılsın
    private let keychainService: String // testler gerçek Keychain kaydına dokunmasın diye ayrı kutu adı verilebilir
    private let refreshKey = "refreshToken" // Keychain'deki kaydın adı

    private var accessToken: String? // bellekteki erişim jetonu | nil: henüz yok (uygulama yeni açıldı ya da çıkış yapıldı)
    // refreshTask: şu an devam eden yenileme işi | nil: yenileme yok | "tek uçuş"un anahtarı: varsa yenisini başlatma, bunu bekle
    private var refreshTask: Task<LoginResponse, Error>?

    init(baseURL: String = APIConfig.baseURL, session: URLSession = .shared, keychainService: String = KeychainStore.defaultService) {
        self.baseURL = baseURL
        self.session = session
        self.keychainService = keychainService
    }

    // keychainServiceForTests: yalnız TESTLER için | testin kendi Keychain kutusunun adını söyler (rotasyonla kaydedilen jetonu doğrulamak için)
    var keychainServiceForTests: String { keychainService }

    // hasStoredSession: Keychain'de yenileme jetonu var mı | NE İŞE YARAR: açılışta "otomatik giriş yapılabilir mi" kararı
    var hasStoredSession: Bool { KeychainStore.get(key: refreshKey, service: keychainService) != nil }

    // currentAccessToken: istek atarken kullanılacak jeton (yoksa nil)
    func currentAccessToken() -> String? { accessToken }

    // signIn: giriş/yenileme başarılı olunca çağrılır | jetonları yerine koyar
    // ÖNEMLİ: yeni yenileme jetonu HEMEN Keychain'e yazılır; sunucu eskisini iptal etti, kaydetmezsek bir sonraki yenileme başarısız olur
    func signIn(_ response: LoginResponse) {
        accessToken = response.accessToken // bellekte
        KeychainStore.set(response.refreshToken, key: refreshKey, service: keychainService) // Keychain'de
    }

    // restore: OTOMATİK GİRİŞ | uygulama açılırken çağrılır | -> LoginUser?: oturum varsa kullanıcı, yoksa nil
    // Keychain'de yenileme jetonu varsa sunucudan yeni jeton ister; başarılıysa kullanıcı şifre yazmadan içeri girer
    // İnternet yoksa (hata fırlar) oturum SİLİNMEZ: kullanıcı sonra tekrar deneyebilir | sunucu "geçersiz" derse silinir (aşağıda)
    func restore() async throws -> LoginUser? {
        guard hasStoredSession else { return nil } // hiç oturum yok → giriş ekranı
        return try await refresh().user
    }

    // tokenAfterFailure: bir istek 401 alınca APIClient bunu çağırır | -> yeni geçerli erişim jetonu
    // failed: 401 alan isteğin kullandığı jeton | NEDEN karşılaştırma: iki istek aynı eski jetonla 401 aldıysa ilki yeniler, ikincisi gelince jeton ZATEN değişmiştir; tekrar yenilemeye gerek yok, yenisini kullanır
    func tokenAfterFailure(of failed: String?) async throws -> String {
        if let task = refreshTask { return try await task.value.accessToken } // yenileme sürüyor → onu bekle (tek uçuş)
        if let current = accessToken, current != failed { return current } // başkası çoktan yeniledi → yeni jetonu kullan
        return try await refresh().accessToken // yenileme gerçekten gerekli
    }

    // refreshAccessToken: bellekte jeton yokken (uygulama yeni açıldı) ilk istekten önce çağrılır
    func refreshAccessToken() async throws -> String { try await refresh().accessToken }

    // refresh: yenilemenin kendisi | TEK UÇUŞ: devam eden varsa onu bekler, yoksa yenisini başlatır
    func refresh() async throws -> LoginResponse {
        if let task = refreshTask { return try await task.value } // zaten yenileniyor → aynı işe bağlan
        let task = Task { try await performRefresh() } // yenileme işini başlat | Task [SWIFT]: arka planda çalışan iş
        refreshTask = task // başkaları görsün diye sakla (await'ten ÖNCE: actor başka işe geçebilir, bu atama onlara yenilemeyi gösterir)
        defer { refreshTask = nil } // iş bitince (başarı ya da hata) temizle | defer [SWIFT]: fonksiyondan çıkarken çalışır
        return try await task.value
    }

    // expireSession: yenileme artık mümkün değil (sunucu reddetti) → yerel oturumu sil ve ekranlara haber ver
    func expireSession() {
        clearLocal()
        NotificationCenter.default.post(name: .sessionExpired, object: nil) // "yayınla": HomeView dinler, giriş ekranına döner
    }

    // signOut: kullanıcı "Çıkış Yap"a bastı
    // ÖNCE yerel oturum silinir (ekran hemen kapansın), SONRA sunucuya haber verilir (jeton orada da iptal edilsin) | sunucu cevap vermese bile çıkış tamamdır (best-effort)
    func signOut() async {
        let stored = KeychainStore.get(key: refreshKey, service: keychainService)
        clearLocal()
        guard let stored else { return }
        var request = URLRequest(url: URL(string: baseURL + "/api/v1/auth/logout")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["refreshToken": stored]) // [String: String] sözlüğü de JSON'a çevrilebilir
        _ = try? await session.data(for: request) // try?: hata olursa yok say | _ = cevabı kullanmayacağız
    }

    // ─── Aşağısı yalnız bu sınıfın içi ───

    private func clearLocal() {
        accessToken = nil
        KeychainStore.remove(key: refreshKey, service: keychainService)
    }

    // performRefresh: yenileme isteğini atar | yenileme için APIClient KULLANILMAZ (sonsuz döngü olurdu: APIClient 401'de buraya gelir)
    private func performRefresh() async throws -> LoginResponse {
        guard let stored = KeychainStore.get(key: refreshKey, service: keychainService) else {
            throw AuthError(message: "Oturum bulunamadı, tekrar giriş yapın.", isSessionExpired: true)
        }
        var request = URLRequest(url: URL(string: baseURL + "/api/v1/auth/refresh")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // cihaz kimliği SABİT olmalı: sunucu jetonu cihaza bağlar, farklıysa reddeder (Security/DeviceID.swift)
        request.httpBody = try JSONEncoder().encode(["refreshToken": stored, "deviceId": DeviceID.current])

        // İnternet yoksa ya da sunucu kapalıysa burada hata fırlar ve oturum SİLİNMEZ (kullanıcı sonra tekrar dener).
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        if (200...299).contains(status) {
            let decoded = try JSONDecoder().decode(LoginResponse.self, from: data)
            signIn(decoded) // rotasyon: YENİ yenileme jetonunu hemen sakla (eskisi sunucuda iptal oldu)
            return decoded
        }
        if status == 400 || status == 401 { // sunucu "bu jeton geçersiz" dedi (süresi doldu, iptal edildi, çalıntı sanıldı, başka cihaz)
            expireSession()
            throw AuthError(message: "Oturum süresi doldu, tekrar giriş yapın.", isSessionExpired: true)
        }
        if status == 429 { throw AuthError(message: "Çok fazla deneme yapıldı. Biraz bekleyip tekrar deneyin.") } // oturum geçerli, silinmez
        throw AuthError(message: "Oturum yenilenemedi.") // sunucu hatası vb.: oturum silinmez
    }
}
