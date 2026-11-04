//
//  LoginViewModel.swift
//  Yukum
//

import Foundation
import Observation

// BU SINIF: giriş ekranının durumu ve mantığı (alanlar, doğrulama, giriş isteği, otomatik giriş, hata)
// BAĞLANTI: View/LoginView.swift kullanır | servisler: Network/AuthService.swift (AuthServicing), Network/AuthSession.swift (SessionRestoring), Security/DeviceID.swift
@Observable
final class LoginViewModel {

    private let auth: AuthServicing
    private let session: SessionRestoring
    private let deviceId: () -> String // () -> String: "çağrılınca metin veren fonksiyon" | gerçekte DeviceID.current, testte sabit değer

    var emailOrPhone = "" // kullanıcının yazdığı e-posta ya da telefon
    var password = ""
    var errorMessage: String? // nil: hata yok
    var isLoading = false // istek sürerken true → düğme kilitlenir
    // isRestoring: uygulama yeni açıldı, kayıtlı oturum aranıyor | true iken giriş formu yerine "Oturum açılıyor" gösterilir (form bir anlığına yanıp sönmesin)
    var isRestoring = true
    var loggedInUser: LoginUser? // giriş başarılıysa dolar → ekran HomeView'ı tam ekran açar | çıkışta ekran nil yapar

    init(auth: AuthServicing = AuthService(), session: SessionRestoring = AuthSession.shared, deviceId: @escaping () -> String = { DeviceID.current }) {
        self.auth = auth
        self.session = session
        self.deviceId = deviceId
    }

    // restoreSession: OTOMATİK GİRİŞ | ekran açılınca bir kez çağrılır
    // Keychain'de yenileme jetonu varsa sunucudan yeni jeton alınır; başarılıysa kullanıcı şifre yazmadan doğrudan ana sayfaya girer
    // Hata olursa (sunucu "geçersiz" dedi ya da internet yok) giriş formu görünür | internet yoksa jeton SİLİNMEZ (AuthSession karar verir)
    func restoreSession() async {
        if let user = try? await session.restore() { loggedInUser = user } // try?: hata olursa nil
        isRestoring = false
    }

    // login: "Giriş yap" düğmesi
    func login() async {
        // 1) Kontrol: boşsa API'ye gitme
        guard !emailOrPhone.isEmpty, !password.isEmpty else {
            errorMessage = "E-posta/telefon ve şifre gerekli."
            return
        }
        isLoading = true // düğme kilitlenir
        errorMessage = nil // eski hatayı temizle
        defer { isLoading = false } // fonksiyondan çıkarken (başarı/hata fark etmez) düğme tekrar açılır

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
