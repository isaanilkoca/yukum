//
//  AuthSession.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: AuthSession (oturumun tek sahibi) ───────────────────────────
// │ SAKLAR    : accessToken (15 dk, bellekte) | refreshToken (30 gün, Keychain'de: Security/KeychainStore)
// │ ÇAĞIRAN   : Networking/APIClient (her istekte jeton, 401'de yenileme) | Services/AuthService.login (signIn) | LoginViewModel.restoreSession (restore) | Views/HomeView (signOut)
// │ YAYINLAR  : Süre dolup yenileme reddedilirse .sessionExpired yayınlar → Views/HomeView dinler (.onReceive) → giriş ekranına döner
// │ KULLANIR  : Security/KeychainStore (jeton), Security/DeviceID (cihaz kimliği), Models/Auth/LoginResponse, Models/Auth/LoginUser
// │ HAZIR (Swift/Apple) [SWIFT] : actor, async, await, defer, guard, throws, try?, Task, extension, static, Error, URLSession, URLRequest, HTTPURLResponse, JSONEncoder, JSONDecoder, NotificationCenter, String, Bool, URL, .contains, .decode, .encode
// │ BİZİM (bizim yazdığımız) [BİZİM] : türler: AuthSession | fonksiyonlar: currentAccessToken, signIn, restore, tokenAfterFailure, refreshAccessToken, refresh, expireSession, signOut, clearLocal, performRefresh | değişken/durumlar: shared, baseURL, session, keychainService, refreshKey, accessToken, refreshTask, keychainServiceForTests, hasStoredSession, task …
// └──────────────────────────────────────────────────────────────────────


// BU SINIF: oturumun TEK sahibi. İki jetonu yönetir ve süresi dolunca otomatik yeniler.
//   erişim jetonu (accessToken)   : 15 dk, her istekte gider, yalnız BELLEKTE durur (diske yazılmaz)
//   yenileme jetonu (refreshToken): 30 gün, yalnız jeton yenilemek için kullanılır, KEYCHAIN'de durur (Security/KeychainStore.swift)
// NEDEN actor: aynı anda birçok istek 401 alabilir (liste + rozet + ...). actor, içindeki değişkenlere AYNI ANDA yalnız bir iş erişsin diye garanti eder.
//   Yenileme jetonu TEK KULLANIMLIK (sunucu rotasyon yapar): iki istek aynı jetonla ayrı ayrı yenileme yapsaydı ikincisi "çalıntı" sayılır ve oturum düşerdi.
//   Çözüm "tek uçuş" (single-flight): ilk istek yenilemeyi başlatır, diğerleri AYNI yenilemenin bitmesini bekler.
// BAĞLANTI: Networking/APIClient.swift (her istekte jeton ister, 401'de yenileme ister) | Services/AuthService.swift (girişte signIn) | Views/LoginView.swift (açılışta restore) | Views/HomeView.swift (çıkışta signOut)
actor AuthSession { // actor [SWIFT]: kendi verisini kendi koruyan sınıf | adı [BİZİM]

    static let shared = AuthSession() // uygulamanın tek oturumu | testlerde kendi örneğimizi oluştururuz (aşağıdaki init) | static [SWIFT]: türün kendisine ait (örnek üretmeden erişilir)

    private let baseURL: String
    private let session: URLSession // URLSession [SWIFT]: postacı | dışarıdan verilebilir ki testlerde sahte postacı takılsın
    private let keychainService: String // testler gerçek Keychain kaydına dokunmasın diye ayrı kutu adı verilebilir
    private let refreshKey = "refreshToken" // Keychain'deki kaydın adı

    private var accessToken: String? // bellekteki erişim jetonu | nil: henüz yok (uygulama yeni açıldı ya da çıkış yapıldı)
    // refreshTask: şu an devam eden yenileme işi | nil: yenileme yok | "tek uçuş"un anahtarı: varsa yenisini başlatma, bunu bekle
    private var refreshTask: Task<LoginResponse, Error>? // Error [SWIFT]: fırlatılabilir hata türü

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
    func restore() async throws -> LoginUser? { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
        guard hasStoredSession else { return nil } // hiç oturum yok → giriş ekranı | guard [SWIFT]: şart sağlanmazsa fonksiyondan erken çık
        return try await refresh().user // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
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
        NotificationCenter.default.post(name: .sessionExpired, object: nil) // "yayınla": HomeView dinler, giriş ekranına döner | NotificationCenter [SWIFT]: uygulama içi anons panosu (biri yayınlar, ilgilenen dinler)
    }

    // signOut: kullanıcı "Çıkış Yap"a bastı
    // ÖNCE yerel oturum silinir (ekran hemen kapansın), SONRA sunucuya haber verilir (jeton orada da iptal edilsin) | sunucu cevap vermese bile çıkış tamamdır (best-effort)
    func signOut() async {
        let stored = KeychainStore.get(key: refreshKey, service: keychainService)
        clearLocal()
        guard let stored else { return }
        var request = URLRequest(url: URL(string: baseURL + "/api/v1/auth/logout")!) // URLRequest [SWIFT]: gidecek istek zarfı (adres, yöntem, başlıklar, gövde)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["refreshToken": stored]) // [String: String] sözlüğü de JSON'a çevrilebilir | try? [SWIFT]: hata olursa çökme, nil ver | JSONEncoder [SWIFT]: struct'ı JSON'a çevirir | .encode [SWIFT]: Swift nesnesinden JSON'a çevirir
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
            throw APIError(message: "Oturum bulunamadı, tekrar giriş yapın.", isSessionExpired: true)
        }
        var request = URLRequest(url: URL(string: baseURL + "/api/v1/auth/refresh")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // cihaz kimliği SABİT olmalı: sunucu jetonu cihaza bağlar, farklıysa reddeder (Security/DeviceID.swift)
        request.httpBody = try JSONEncoder().encode(["refreshToken": stored, "deviceId": DeviceID.current])

        // İnternet yoksa ya da sunucu kapalıysa burada hata fırlar ve oturum SİLİNMEZ (kullanıcı sonra tekrar dener).
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0 // HTTPURLResponse [SWIFT]: sunucunun cevap bilgisi (durum kodu dahil)

        if (200...299).contains(status) { // .contains [SWIFT]: içinde var mı diye bakar
            let decoded = try JSONDecoder().decode(LoginResponse.self, from: data) // JSONDecoder [SWIFT]: JSON'u struct'a çevirir | .decode [SWIFT]: JSON'dan Swift nesnesine çevirir
            signIn(decoded) // rotasyon: YENİ yenileme jetonunu hemen sakla (eskisi sunucuda iptal oldu)
            return decoded
        }
        if status == 400 || status == 401 { // sunucu "bu jeton geçersiz" dedi (süresi doldu, iptal edildi, çalıntı sanıldı, başka cihaz)
            expireSession()
            throw APIError(message: "Oturum süresi doldu, tekrar giriş yapın.", isSessionExpired: true)
        }
        if status == 429 { throw APIError(message: "Çok fazla deneme yapıldı. Biraz bekleyip tekrar deneyin.") } // oturum geçerli, silinmez
        throw APIError(message: "Oturum yenilenemedi.") // sunucu hatası vb.: oturum silinmez
    }
}

// AuthSession, kendi sözleşmesini karşılar (Services/Protocols/): ViewModel'ler somut sınıfa değil sözleşmeye bağlıdır, testte sahtesi verilir
extension AuthSession: SessionRestoring, SessionSigningOut {} // extension [SWIFT]: mevcut türe sonradan özellik/uyum ekler
