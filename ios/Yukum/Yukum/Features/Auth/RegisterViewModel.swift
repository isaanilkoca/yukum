//
//  RegisterViewModel.swift
//  Yukum
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: RegisterViewModel ───────────────────────────────────────────
// │ EKRAN     : Features/Auth/RegisterView (@State private var viewModel) — Yük Veren kayıt formu; Features/Auth/RoleSelectionView açar
// │ SERVİS    : Features/Auth/AuthServicing → AuthService.register → POST /api/v1/auth/register/shipper
// │ MODEL     : RegisterRequest (giden), RegisterResponse (gelen)
// │ AKIŞ      : Alanlar $viewModel ile doldurulur → "Kayıt Ol" → register(): doğrula → RegisterRequest → AuthService → isSuccess / errorMessage
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: Yük Veren kayıt formunun durumu ve mantığı (alanlar, doğrulama, paket hazırlama, gönderme, sonuç)
// BAĞLANTI: Features/Auth/RegisterView.swift kullanır | servis: Features/Auth/AuthService.swift (AuthServicing sözleşmesi)
// ⮕ KULLANIM [RegisterViewModel]: kullanır: RegisterView › viewModel, RegisterViewModelTests (test)
@Observable // @Observable [SWIFT]: sınıfı gözlemlenebilir yapar: değişkenleri değişince onları okuyan ekranlar kendiliğinden yenilenir
final class RegisterViewModel {

    // ⮕ KULLANIM [auth]: okur: RegisterViewModel › register()
    private let auth: AuthServicing

    // ⮕ ZİNCİR: Features/Auth/RegisterView: TextField'lar ve Toggle, $viewModel ile doğrudan buraya yazar | register() okur, RegisterRequest alanlarına koyar
    // ⮕ KULLANIM [fullName]: okur: RegisterViewModel › register(), RegisterViewModelTests (test) | bağlar(okur+yazar): RegisterView › body | YAZAR: RegisterViewModelTests (test)
    var fullName = "" // ad soyad
    // ⮕ KULLANIM [email]: okur: RegisterViewModel › register(), RegisterViewModelTests (test) | bağlar(okur+yazar): RegisterView › body | YAZAR: RegisterViewModelTests (test)
    var email = ""
    // ⮕ KULLANIM [phone]: okur: RegisterViewModel › register(), RegisterViewModelTests (test) | bağlar(okur+yazar): RegisterView › body | YAZAR: RegisterViewModelTests (test)
    var phone = ""
    // ⮕ KULLANIM [password]: okur: RegisterViewModel › register(), RegisterViewModelTests (test) | bağlar(okur+yazar): RegisterView › body | YAZAR: RegisterViewModelTests (test)
    var password = ""
    // ⮕ KULLANIM [companyName]: okur: RegisterViewModel › register(), RegisterViewModelTests (test) | bağlar(okur+yazar): RegisterView › body
    var companyName = "" // firma adı, isteğe bağlı (boşsa nil gider)
    // ⮕ KULLANIM [kvkkAccepted]: okur: RegisterViewModel › register() | bağlar(okur+yazar): RegisterView › body | YAZAR: RegisterViewModelTests (test)
    var kvkkAccepted = false // KVKK Toggle'ı
    // ⮕ ZİNCİR: Features/Auth/RegisterView: kırmızı hata yazısı (doğrulama mesajı ya da sunucunun Türkçe mesajı)
    // ⮕ KULLANIM [errorMessage]: YAZAR: RegisterViewModel › register() | okur: RegisterViewModelTests (test)
    var errorMessage: String?
    // ⮕ ZİNCİR: Features/Auth/RegisterView: "Kayıt Ol" düğmesi .disabled(viewModel.isLoading) — çift tıklamayı engeller
    // ⮕ KULLANIM [isLoading]: YAZAR: RegisterViewModel › register() | okur: RegisterView › body, RegisterViewModelTests (test)
    var isLoading = false
    // ⮕ ZİNCİR: Features/Auth/RegisterView: true olunca yeşil "Kayıt başarılı" yazısı
    // ⮕ KULLANIM [isSuccess]: YAZAR: RegisterViewModel › register() | okur: RegisterView › body, RegisterViewModelTests (test)
    var isSuccess = false

    // GEÇİCİ BORÇ: kayıtta il seçimi henüz yok, API il numarası ister → şimdilik sabit İstanbul (34). İl seçimi eklenince bu sabit kalkar.
    // ⮕ KULLANIM [defaultCityId]: okur: CarrierRegisterViewModelTests (test), RegisterViewModelTests (test)
    static let defaultCityId = 34 // static [SWIFT]: türün kendisine ait (örnek üretmeden erişilir)

    init(auth: AuthServicing = AuthService()) { self.auth = auth }

    // register: "Kayıt Ol" düğmesi | ⮕ ZİNCİR: Features/Auth/RegisterView: Button { Task { await viewModel.register() } } → AuthService.register(RegisterRequest) → RegisterResponse (kullanılmaz, yalnız başarı)
    // ⮕ KULLANIM [register]: çağırır: RegisterViewModel › register(), RegisterView › body, RegisterViewModelTests (test)
    func register() async { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz)
        // ---- 1) KONTROLLER: API'ye gitmeden ekranda yakalıyoruz ----
        let name = fullName.trimmingCharacters(in: .whitespaces), mail = email.trimmingCharacters(in: .whitespaces), tel = phone.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !mail.isEmpty, !tel.isEmpty, !password.isEmpty else { // guard [SWIFT]: şart sağlanmazsa fonksiyondan erken çık
            errorMessage = "Lütfen zorunlu alanları doldurun."
            return
        }
        guard kvkkAccepted else {
            errorMessage = "KVKK metnini onaylamanız gerekir."
            return
        }

        // ---- 2) PAKETİ HAZIRLA ---- (parametre sırası RegisterRequest'teki alan sırasıyla aynı olmalı)
        let body = RegisterRequest(fullName: name, email: mail, password: password, phone: tel, cityId: Self.defaultCityId,
                                   companyName: companyName.isEmpty ? nil : companyName, // boşsa nil: JSON'a hiç yazılmaz
                                   kvkkAccepted: kvkkAccepted)

        // ---- 3) GÖNDER ----
        isLoading = true // düğme kilitlenir
        errorMessage = nil // eski hatayı temizle
        isSuccess = false
        defer { isLoading = false } // düğme tekrar açılır | defer [SWIFT]: fonksiyondan çıkarken çalışacak kod
        do {
            _ = try await auth.register(body) // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
            isSuccess = true // yeşil mesaj
        } catch {
            if let message = error.userMessage { errorMessage = message } // API'nin Türkçe mesajı (örn. "Bu e-posta zaten kayıtlı.")
        }
    }
}
