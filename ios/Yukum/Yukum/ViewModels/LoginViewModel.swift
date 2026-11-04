//
//  LoginViewModel.swift
//  Yukum
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: LoginViewModel ──────────────────────────────────────────────
// │ EKRAN     : Views/LoginView (@State private var viewModel) — uygulamanın ilk ekranı (App/ContentView açar)
// │ SERVİS    : Models/Services/Protocols/AuthServicing → AuthService.login | SessionRestoring → Models/Networking/AuthSession.restore | Models/Security/DeviceID
// │ MODEL     : LoginRequest (giden), LoginResponse (gelen), LoginUser (giriş yapan kişi)
// │ AKIŞ      : Açılış: restoreSession() otomatik giriş | Giriş: login() → AuthService → jetonlar AuthSession'a → loggedInUser dolar → View HomeView'ı açar
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: giriş ekranının durumu ve mantığı (alanlar, doğrulama, giriş isteği, otomatik giriş, hata)
// BAĞLANTI: Views/LoginView.swift kullanır | servisler: Models/Services/AuthService.swift (AuthServicing), Models/Networking/AuthSession.swift (SessionRestoring), Models/Security/DeviceID.swift
// ⮕ KULLANIM [LoginViewModel]: kullanır: LoginView › viewModel, LoginViewModelTests (test)
@Observable // @Observable [SWIFT]: sınıfı gözlemlenebilir yapar: değişkenleri değişince onları okuyan ekranlar kendiliğinden yenilenir
final class LoginViewModel {

    // ⮕ KULLANIM [auth]: okur: LoginViewModel › login()
    private let auth: AuthServicing
    // ⮕ KULLANIM [session]: okur: LoginViewModel › restoreSession()
    private let session: SessionRestoring
    // ⮕ KULLANIM [deviceId]: okur: LoginViewModel › login(), LoginViewModelTests (test)
    private let deviceId: () -> String // () -> String: "çağrılınca metin veren fonksiyon" | gerçekte DeviceID.current, testte sabit değer

    // ⮕ ZİNCİR: Views/LoginView: TextField("Email veya Telefon", text: $viewModel.emailOrPhone) | login() baş/son boşluğu temizleyip LoginRequest.emailOrPhone'a koyar
    // ⮕ KULLANIM [emailOrPhone]: okur: LoginViewModel › login(), LoginViewModelTests (test) | bağlar(okur+yazar): LoginView › body | YAZAR: LoginViewModelTests (test)
    var emailOrPhone = "" // kullanıcının yazdığı e-posta ya da telefon
    // ⮕ ZİNCİR: Views/LoginView: SecureField("Şifre", text: $viewModel.password) | LoginRequest.password | başarılı girişten sonra boşaltılır
    // ⮕ KULLANIM [password]: okur: LoginViewModel › login(), LoginViewModelTests (test) | YAZAR: LoginViewModel › login(), LoginViewModelTests (test) | bağlar(okur+yazar): LoginView › body
    var password = ""
    // ⮕ ZİNCİR: Views/LoginView: if let errorMessage → kırmızı yazı | "E-posta veya şifre hatalı." gibi sunucu mesajı
    // ⮕ KULLANIM [errorMessage]: YAZAR: LoginViewModel › login() | okur: LoginViewModelTests (test)
    var errorMessage: String? // nil: hata yok
    // ⮕ ZİNCİR: Views/LoginView: "Giriş yap" düğmesi .disabled(viewModel.isLoading)
    // ⮕ KULLANIM [isLoading]: YAZAR: LoginViewModel › login() | okur: LoginView › body, LoginViewModelTests (test)
    var isLoading = false // istek sürerken true → düğme kilitlenir
    // isRestoring: uygulama yeni açıldı, kayıtlı oturum aranıyor | true iken giriş formu yerine "Oturum açılıyor" gösterilir (form bir anlığına yanıp sönmesin)
    // ⮕ ZİNCİR: Views/LoginView: true iken .overlay ile "Oturum açılıyor..." çarkı gösterilir (form bir an görünmesin) | restoreSession() bitince false
    // ⮕ KULLANIM [isRestoring]: YAZAR: LoginViewModel › restoreSession() | okur: LoginView › body, LoginViewModelTests (test)
    var isRestoring = true
    // ⮕ ZİNCİR: Views/LoginView: .fullScreenCover(item: $viewModel.loggedInUser) { user in HomeView(user: user) } — dolunca ana sayfa açılır, HomeView'ın dismiss()'i nil yapar | MODEL: LoginUser
    // ⮕ KULLANIM [loggedInUser]: YAZAR: LoginViewModel › restoreSession(), LoginViewModel › login() | bağlar(okur+yazar): LoginView › body | okur: LoginViewModelTests (test)
    var loggedInUser: LoginUser? // giriş başarılıysa dolar → ekran HomeView'ı tam ekran açar | çıkışta ekran nil yapar

    init(auth: AuthServicing = AuthService(), session: SessionRestoring = AuthSession.shared, deviceId: @escaping () -> String = { DeviceID.current }) { // @escaping [SWIFT]: closure fonksiyon bittikten sonra da saklanıp çağrılabilir
        self.auth = auth
        self.session = session
        self.deviceId = deviceId
    }

    // ═══ restoreSession() — BİZİM fonksiyon (burada tanımlı) ═══
    // ÇAĞIRAN : LoginView.task { await viewModel.restoreSession() } — ekran açılınca bir kez
    // AMAÇ    : Keychain'de kayıtlı oturum varsa şifre sormadan doğrudan ana sayfaya al
    // `async`  → [Swift anahtar sözcüğü] bu fonksiyonun içinde `await` ile beklenebilir; bekleme sırasında ekran donmaz
    func restoreSession() async {
        // if let user = try? await session.restore() { loggedInUser = user }
        //   session            → BİZİM değişken (satır 25, tipi SessionRestoring); gerçekte Models/Networking/AuthSession.shared
        //   session.restore()  → BİZİM fonksiyon (Models/Networking/AuthSession.swift): Keychain'deki yenileme jetonuyla sunucudan yeni jeton alır → LoginUser? döner
        //   await              → [Swift] cevap gelene kadar bekle
        //   try?               → [Swift] restore() hata fırlatırsa çökme, sonucu nil say (şifre formu görünür)
        //   if let user = ...  → [Swift] sonuç nil DEĞİLSE içindekini `user` adıyla al (user: yalnız bu süslü parantez içinde yaşar)
        //   loggedInUser = user → BİZİM değişken (satır 47): dolunca LoginView'daki .fullScreenCover HomeView(user:) açar
        if let user = try? await session.restore() { loggedInUser = user }
        // isRestoring → BİZİM değişken (satır 44): false olunca LoginView "Oturum açılıyor" çarkını kaldırır, form görünür
        isRestoring = false
    }

    // ═══ login() — BİZİM fonksiyon ═══
    // ÇAĞIRAN : LoginView "Giriş yap" düğmesi: Task { await viewModel.login() }
    // AKIŞ    : kontrol → LoginRequest paketi → auth.login → AuthService → APIClient → POST /api/v1/auth/login → LoginResponse → loggedInUser
    func login() async {
        // guard !emailOrPhone.isEmpty, !password.isEmpty else { ... return }
        //   guard  → [Swift] şart sağlanmazsa else bloğuna gir ve fonksiyondan çık (API'ye hiç gidilmez)
        //   emailOrPhone, password → BİZİM değişkenler (satır 31, 34): LoginView'daki TextField/SecureField doğrudan bunlara yazar ($ bağı)
        //   errorMessage → BİZİM değişken (satır 37): LoginView kırmızı yazı olarak gösterir
        guard !emailOrPhone.isEmpty, !password.isEmpty else {
            errorMessage = "E-posta/telefon ve şifre gerekli."
            return
        }
        // isLoading → BİZİM (satır 40): true iken LoginView düğmeyi kilitler | errorMessage = nil: eski hata silinir
        isLoading = true
        errorMessage = nil
        // defer { ... } → [Swift] fonksiyondan HER çıkışta (başarı/hata/return) çalışır: düğme tekrar açılır
        defer { isLoading = false }

        // LoginRequest(...) → BİZİM model (Models/Auth/LoginRequest.swift): API'ye gidecek JSON paketi
        //   .trimmingCharacters(in: .whitespaces) → [Swift/Foundation] baştaki-sondaki boşlukları keser
        //   deviceId()    → BİZİM değişken (satır 27) fonksiyon gibi çağrılır: gerçekte Models/Security/DeviceID.current (Keychain'deki sabit cihaz kimliği)
        let body = LoginRequest(emailOrPhone: emailOrPhone.trimmingCharacters(in: .whitespaces), password: password, deviceId: deviceId())
        do {
            // auth.login(body) → auth: BİZİM (satır 23, tipi AuthServicing) → gerçekte Models/Services/AuthService.login: isteği atar, jetonları AuthSession'a verir
            //   try await → [Swift] hata fırlatabilir + cevap gelene kadar bekle | response: LoginResponse (Models/Auth/LoginResponse.swift)
            let response = try await auth.login(body)
            password = "" // şifre bellekte/ekranda kalmasın
            // response.user → LoginResponse içindeki LoginUser (ad, rol) → loggedInUser'a yazılır → LoginView HomeView'ı açar
            loggedInUser = response.user
        } catch {
            // catch → [Swift] try başarısız olursa buraya düşer | error: Swift'in verdiği hata
            // error.userMessage → BİZİM (Models/Networking/Error+UserMessage.swift): hatayı Türkçe metne çevirir (iptal ise nil → yazı gösterilmez)
            if let message = error.userMessage { errorMessage = message }
        }
    }
}
