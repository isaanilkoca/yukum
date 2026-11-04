//
//  LoginViewModel.swift
//  Yukum
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: LoginViewModel ──────────────────────────────────────────────
// │ EKRAN     : Views/LoginView (@State private var viewModel) — uygulamanın ilk ekranı (App/ContentView açar)
// │ SERVİS    : Services/Protocols/AuthServicing → AuthService.login | SessionRestoring → Networking/AuthSession.restore | Security/DeviceID
// │ MODEL     : LoginRequest (giden), LoginResponse (gelen), LoginUser (giriş yapan kişi)
// │ AKIŞ      : Açılış: restoreSession() otomatik giriş | Giriş: login() → AuthService → jetonlar AuthSession'a → loggedInUser dolar → View HomeView'ı açar
// │ HAZIR (Swift/Apple) [SWIFT] : @Observable, @escaping, async, await, defer, guard, try?, String, Observation
// │ BİZİM (bizim yazdığımız) [BİZİM] : türler: LoginViewModel | fonksiyonlar: restoreSession, login | değişken/durumlar: auth, session, deviceId, emailOrPhone, password, errorMessage, isLoading, isRestoring, loggedInUser, user …
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: giriş ekranının durumu ve mantığı (alanlar, doğrulama, giriş isteği, otomatik giriş, hata)
// BAĞLANTI: Views/LoginView.swift kullanır | servisler: Services/AuthService.swift (AuthServicing), Networking/AuthSession.swift (SessionRestoring), Security/DeviceID.swift
@Observable // @Observable [SWIFT]: sınıfı gözlemlenebilir yapar: değişkenleri değişince onları okuyan ekranlar kendiliğinden yenilenir
final class LoginViewModel {

    private let auth: AuthServicing
    private let session: SessionRestoring
    private let deviceId: () -> String // () -> String: "çağrılınca metin veren fonksiyon" | gerçekte DeviceID.current, testte sabit değer

    // ⮕ ZİNCİR: Views/LoginView: TextField("Email veya Telefon", text: $viewModel.emailOrPhone) | login() baş/son boşluğu temizleyip LoginRequest.emailOrPhone'a koyar
    var emailOrPhone = "" // kullanıcının yazdığı e-posta ya da telefon
    // ⮕ ZİNCİR: Views/LoginView: SecureField("Şifre", text: $viewModel.password) | LoginRequest.password | başarılı girişten sonra boşaltılır
    var password = ""
    // ⮕ ZİNCİR: Views/LoginView: if let errorMessage → kırmızı yazı | "E-posta veya şifre hatalı." gibi sunucu mesajı
    var errorMessage: String? // nil: hata yok
    // ⮕ ZİNCİR: Views/LoginView: "Giriş yap" düğmesi .disabled(viewModel.isLoading)
    var isLoading = false // istek sürerken true → düğme kilitlenir
    // isRestoring: uygulama yeni açıldı, kayıtlı oturum aranıyor | true iken giriş formu yerine "Oturum açılıyor" gösterilir (form bir anlığına yanıp sönmesin)
    // ⮕ ZİNCİR: Views/LoginView: true iken .overlay ile "Oturum açılıyor..." çarkı gösterilir (form bir an görünmesin) | restoreSession() bitince false
    var isRestoring = true
    // ⮕ ZİNCİR: Views/LoginView: .fullScreenCover(item: $viewModel.loggedInUser) { user in HomeView(user: user) } — dolunca ana sayfa açılır, HomeView'ın dismiss()'i nil yapar | MODEL: LoginUser
    var loggedInUser: LoginUser? // giriş başarılıysa dolar → ekran HomeView'ı tam ekran açar | çıkışta ekran nil yapar

    init(auth: AuthServicing = AuthService(), session: SessionRestoring = AuthSession.shared, deviceId: @escaping () -> String = { DeviceID.current }) { // @escaping [SWIFT]: closure fonksiyon bittikten sonra da saklanıp çağrılabilir
        self.auth = auth
        self.session = session
        self.deviceId = deviceId
    }

    // restoreSession: OTOMATİK GİRİŞ | ekran açılınca bir kez çağrılır
    // Keychain'de yenileme jetonu varsa sunucudan yeni jeton alınır; başarılıysa kullanıcı şifre yazmadan doğrudan ana sayfaya girer
    // Hata olursa (sunucu "geçersiz" dedi ya da internet yok) giriş formu görünür | internet yoksa jeton SİLİNMEZ (AuthSession karar verir)
    // ⮕ ZİNCİR: Views/LoginView: .task { await viewModel.restoreSession() } | Networking/AuthSession.restore() — Keychain'de yenileme jetonu varsa şifresiz giriş
    func restoreSession() async { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz)
        if let user = try? await session.restore() { loggedInUser = user } // try?: hata olursa nil | await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder) | try? [SWIFT]: hata olursa çökme, nil ver
        isRestoring = false
    }

    // login: "Giriş yap" düğmesi
    // ⮕ ZİNCİR: Views/LoginView: Button("Giriş yap") { Task { await viewModel.login() } } | AuthService.login(LoginRequest) → LoginResponse (jetonlar AuthSession'a verilir)
    func login() async {
        // 1) Kontrol: boşsa API'ye gitme
        guard !emailOrPhone.isEmpty, !password.isEmpty else { // guard [SWIFT]: şart sağlanmazsa fonksiyondan erken çık
            errorMessage = "E-posta/telefon ve şifre gerekli."
            return
        }
        isLoading = true // düğme kilitlenir
        errorMessage = nil // eski hatayı temizle
        defer { isLoading = false } // fonksiyondan çıkarken (başarı/hata fark etmez) düğme tekrar açılır | defer [SWIFT]: fonksiyondan çıkarken çalışacak kod

        // 2) Paketi hazırla | deviceId: bu cihaza ait SABİT kimlik, sunucu yenileme jetonunu cihaza bağlar
        let body = LoginRequest(emailOrPhone: emailOrPhone.trimmingCharacters(in: .whitespaces), password: password, deviceId: deviceId())
        // 3) Gönder | jetonlar AuthService.login içinde AuthSession'a verilir (erişim jetonu belleğe, yenileme jetonu Keychain'e)
        do {
            let response = try await auth.login(body)
            password = "" // başarılı girişten sonra şifre ekranda/bellekte kalmasın (çıkışta form boş döner)
            loggedInUser = response.user
        } catch {
            if let message = error.userMessage { errorMessage = message } // "E-posta veya şifre hatalı." gibi sunucunun Türkçe mesajı
        }
    }
}
