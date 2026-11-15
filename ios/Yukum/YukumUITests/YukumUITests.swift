//
//  YukumUITests.swift
//  YukumUITests
//
//  Arayüz testleri (XCUITest, 15 Kasım): uygulamayı gerçekten açar, ekrana dokunur, yazı yazar — kullanıcının yaptığı gibi.
//

import XCTest

// ┌─ BAĞLANTI HARİTASI: YukumUITests ─────────────────────────────────────────────
// │ NE        : Birim testleri (YukumTests) ViewModel mantığını sunucusuz sınar; bunlar EKRANLARIN birbirine doğru bağlandığını sınar
// │ BAŞLANGIÇ : launchClean() → "-uiTestReset" (App/YukumApp.init, yalnız Debug) → kayıtlı oturum silinir → her test giriş ekranından başlar
// │ BULMA     : alanlar sabit kimlikle bulunur (.accessibilityIdentifier: "login.email", "login.submit", "home.profile"...) → metin değişse de test kırılmaz
// │ İKİ GRUP  : (1) sunucusuz: form kontrolleri, sayfa geçişleri — her zaman çalışır
// │             (2) sunuculu: gerçek giriş/çıkış — API (localhost:5054) kapalıysa ATLANIR (XCTSkip), başarısız sayılmaz
// │ HESAP     : sunuculu testler yerel DB'deki deneme hesabını kullanır (tema.shipper@example.com / Deneme123!, e-postası doğrulanmış)
// └──────────────────────────────────────────────────────────────────────
final class YukumUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false // ilk hatada dur: sonraki adımlar zaten anlamsız olur
        app = XCUIApplication()
    }

    // Temiz açılış: kayıtlı oturum yok → giriş formu görünene kadar bekle (açılışta "Oturum açılıyor" kısa süre görünür)
    private func launchClean() {
        app.launchArguments = ["-uiTestReset"]
        app.launch()
        XCTAssertTrue(app.buttons["login.submit"].waitForExistence(timeout: 15), "Giriş formu açılmadı")
    }

    private func type(_ text: String, into element: XCUIElement) {
        element.tap()
        element.typeText(text)
    }

    // API ayakta mı? Değilse sunucu gerektiren test atlanır (bilgisayarda API kapalıyken test takımı kırmızı olmasın)
    private func requireAPI() throws {
        var request = URLRequest(url: URL(string: "http://localhost:5054/api/v1/cities")!)
        request.timeoutInterval = 3
        let done = expectation(description: "API")
        var ok = false
        URLSession.shared.dataTask(with: request) { _, response, _ in
            ok = (response as? HTTPURLResponse)?.statusCode == 200
            done.fulfill()
        }.resume()
        wait(for: [done], timeout: 5)
        try XCTSkipUnless(ok, "API kapalı (localhost:5054): sunucu gerektiren test atlandı")
    }

    // Sistem izin pencereleri (bildirim / konum) çıkarsa kapat: testin akışını kesmesin
    private func dismissSystemAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["İzin Verme", "Don’t Allow", "Don't Allow", "İzin Ver", "Allow"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 1) { button.tap(); return }
        }
    }

    // MARK: - 1) Sunucusuz: giriş ekranı

    @MainActor
    func testLogin_withEmptyFields_showsAMessage_andStaysOnTheForm() {
        launchClean()

        app.buttons["login.submit"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["login.error"].waitForExistence(timeout: 3), "Boş formda hata yazısı çıkmadı")
        XCTAssertTrue(app.staticTexts["E-posta/telefon ve şifre gerekli."].exists)
        XCTAssertTrue(app.buttons["login.submit"].exists) // hâlâ giriş ekranındayız
    }

    @MainActor
    func testForgotPassword_opensWithTheTypedEmail_andCanBeCancelled() {
        launchClean()
        type("ayse@ornek.com", into: app.textFields["login.email"])

        app.buttons["login.forgot"].tap()

        let identity = app.textFields["forgot.identity"]
        XCTAssertTrue(identity.waitForExistence(timeout: 5), "Şifremi unuttum sayfası açılmadı")
        XCTAssertEqual(identity.value as? String, "ayse@ornek.com") // giriş ekranında yazılan e-posta taşındı
        XCTAssertTrue(app.buttons["Kod gönder"].exists)

        app.buttons["Vazgeç"].tap()
        XCTAssertTrue(app.buttons["login.submit"].waitForExistence(timeout: 5)) // giriş ekranına döndü
    }

    // MARK: - 2) Sunucusuz: kayıt ekranı

    @MainActor
    func testRegistration_checksRequiredFieldsBeforeCallingTheServer() {
        launchClean()
        app.buttons["login.register"].tap()

        let submit = app.buttons["register.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5), "Kayıt ekranı açılmadı")
        submit.tap()

        XCTAssertTrue(app.descendants(matching: .any)["register.error"].waitForExistence(timeout: 3), "Boş kayıt formunda hata çıkmadı")
        XCTAssertTrue(app.staticTexts["Lütfen zorunlu alanları doldurun."].exists)
    }

    @MainActor
    func testRegistration_termsOfUse_canBeRead() {
        launchClean()
        app.buttons["login.register"].tap()
        XCTAssertTrue(app.buttons["register.submit"].waitForExistence(timeout: 5))

        let link = app.buttons["Kullanım Koşulları'nı oku"]
        if !link.isHittable { app.swipeUp() } // küçük ekranda form kayar
        link.tap()

        XCTAssertTrue(app.navigationBars["Kullanım Koşulları"].waitForExistence(timeout: 5), "Kullanım Koşulları açılmadı")
        XCTAssertTrue(app.staticTexts["Kötüye kullanıma sıfır tolerans"].exists) // Apple 1.2 maddesi metinde
        app.buttons["Kapat"].tap()
        XCTAssertTrue(app.buttons["register.submit"].waitForExistence(timeout: 5))
    }

    // MARK: - 3) Sunuculu: gerçek giriş

    @MainActor
    func testLogin_withAWrongPassword_showsTheServerMessage() throws {
        try requireAPI()
        launchClean()
        type("yok.boyle.biri@example.com", into: app.textFields["login.email"])
        type("Yanlis12345", into: app.secureTextFields["login.password"])

        app.buttons["login.submit"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["login.error"].waitForExistence(timeout: 10), "Sunucu hatası ekrana gelmedi")
        XCTAssertTrue(app.staticTexts["E-posta veya şifre hatalı."].exists) // olmayan hesap ile yanlış şifre aynı mesaj (güvenlik)
    }

    @MainActor
    func testShipper_logsIn_opensProfile_andSignsOut() throws {
        try requireAPI()
        launchClean()
        app.segmentedControls.buttons["Yük Veren"].tap()
        type("tema.shipper@example.com", into: app.textFields["login.email"])
        type("Deneme123!", into: app.secureTextFields["login.password"])

        app.buttons["login.submit"].tap()
        dismissSystemAlerts()

        let profile = app.buttons["home.profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 20), "Giriş sonrası ana ekran açılmadı")
        profile.tap()
        dismissSystemAlerts()

        let signOut = app.buttons["profile.signout"]
        XCTAssertTrue(signOut.waitForExistence(timeout: 10), "Profil sayfası açılmadı")
        if !signOut.isHittable { app.swipeUp() }
        signOut.tap()

        XCTAssertTrue(app.buttons["login.submit"].waitForExistence(timeout: 15), "Çıkıştan sonra giriş ekranına dönülmedi")
    }

    @MainActor
    func testRelaunch_afterLogin_skipsTheLoginScreen() throws {
        try requireAPI()
        launchClean()
        type("tema.carrier@example.com", into: app.textFields["login.email"])
        type("Deneme123!", into: app.secureTextFields["login.password"])
        app.segmentedControls.buttons["Taşımacı"].tap()
        app.buttons["login.submit"].tap()
        dismissSystemAlerts()
        XCTAssertTrue(app.buttons["home.profile"].waitForExistence(timeout: 20))

        // Bayraksız yeniden açılış: Keychain'deki yenileme jetonuyla otomatik giriş (beni hatırla)
        app.terminate()
        app.launchArguments = []
        app.launch()
        dismissSystemAlerts()

        XCTAssertTrue(app.buttons["home.profile"].waitForExistence(timeout: 20), "Otomatik giriş çalışmadı")
    }
}
