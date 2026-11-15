//
//  CarrierRegisterViewModel.swift
//  Yukum
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: CarrierRegisterViewModel ───────────────────────────────────
// │ EKRAN     : Views/CarrierRegisterView (@State private var viewModel) — Taşımacı kayıt formu; Views/RoleSelectionView açar
// │ SERVİS    : Models/Services/Protocols/AuthServicing → AuthService.registerCarrier → POST /api/v1/auth/register/carrier
// │ MODEL     : RegisterCarrierRequest (içinde [VehicleRequest]) (giden), RegisterResponse (gelen), VehicleType (araç Picker'ı)
// │ AKIŞ      : Alanlar $viewModel ile doldurulur → "Kayıt Ol" → register(): doğrula → RegisterCarrierRequest (araçsız, 15 Kasım) → AuthService
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: Taşımacı kayıt formunun durumu ve mantığı (kişi alanları + tek araç, doğrulama, paket hazırlama, gönderme, sonuç)
// BAĞLANTI: Views/CarrierRegisterView.swift kullanır | servis: Models/Services/AuthService.swift (AuthServicing sözleşmesi)
// ⮕ KULLANIM [CarrierRegisterViewModel]: kullanır: CarrierRegisterView › viewModel, CarrierRegisterViewModelTests (test)
@Observable // @Observable [SWIFT]: sınıfı gözlemlenebilir yapar: değişkenleri değişince onları okuyan ekranlar kendiliğinden yenilenir
final class CarrierRegisterViewModel {

    // ⮕ KULLANIM [auth]: okur: CarrierRegisterViewModel › register()
    private let auth: AuthServicing

    // ⮕ ZİNCİR: Views/CarrierRegisterView: TextField'lar, Picker ve Toggle $viewModel ile doğrudan buraya yazar | register() okur
    // ⮕ KULLANIM [fullName]: okur: CarrierRegisterViewModel › register() | bağlar(okur+yazar): CarrierRegisterView › body | YAZAR: CarrierRegisterViewModelTests (test)
    var fullName = "" // ad soyad / firma
    // ⮕ KULLANIM [email]: okur: CarrierRegisterViewModel › register() | bağlar(okur+yazar): CarrierRegisterView › body | YAZAR: CarrierRegisterViewModelTests (test)
    var email = ""
    // ⮕ KULLANIM [phone]: okur: CarrierRegisterViewModel › register() | bağlar(okur+yazar): CarrierRegisterView › body | YAZAR: CarrierRegisterViewModelTests (test)
    var phone = ""
    // ⮕ KULLANIM [password]: okur: CarrierRegisterViewModel › register() | bağlar(okur+yazar): CarrierRegisterView › body | YAZAR: CarrierRegisterViewModelTests (test)
    var password = ""
    // ⮕ KULLANIM [kvkkAccepted]: okur: CarrierRegisterViewModel › register() | bağlar(okur+yazar): CarrierRegisterView › body | YAZAR: CarrierRegisterViewModelTests (test)
    var kvkkAccepted = false
    var termsAccepted = false // 15 Kasım: Kullanım Koşulları kutusu (FormConsent document: .terms)
    // ⮕ ZİNCİR: Views/CarrierRegisterView: kırmızı hata yazısı
    // ⮕ KULLANIM [errorMessage]: YAZAR: CarrierRegisterViewModel › register() | okur: CarrierRegisterViewModelTests (test)
    var errorMessage: String?
    // ⮕ ZİNCİR: Views/CarrierRegisterView: "Kayıt Ol" düğmesi .disabled(viewModel.isLoading)
    // ⮕ KULLANIM [isLoading]: YAZAR: CarrierRegisterViewModel › register() | okur: CarrierRegisterView › body
    var isLoading = false
    // ⮕ ZİNCİR: Views/CarrierRegisterView: true olunca yeşil başarı yazısı
    // ⮕ KULLANIM [isSuccess]: YAZAR: CarrierRegisterViewModel › register() | okur: CarrierRegisterView › body, CarrierRegisterViewModelTests (test)
    var isSuccess = false

    init(auth: AuthServicing = AuthService()) { self.auth = auth }

    // register: "Kayıt Ol" düğmesi | ⮕ ZİNCİR: Views/CarrierRegisterView: Button { Task { await viewModel.register() } } → AuthService.registerCarrier(RegisterCarrierRequest) → RegisterResponse
    // ⮕ KULLANIM [register]: çağırır: CarrierRegisterView › body, CarrierRegisterViewModelTests (test)
    func register() async { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz)
        // ---- 1) KONTROLLER ----
        let name = fullName.trimmingCharacters(in: .whitespaces), mail = email.trimmingCharacters(in: .whitespaces), tel = phone.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !mail.isEmpty, !tel.isEmpty, !password.isEmpty else { // guard [SWIFT]: şart sağlanmazsa fonksiyondan erken çık
            errorMessage = "Lütfen zorunlu alanları doldurun !"
            return
        }
        guard kvkkAccepted else {
            errorMessage = "KVKK metnini onaylamanız gerekir."
            return
        }
        guard termsAccepted else { // 15 Kasım: Kullanım Koşulları ayrı ve zorunlu (Apple 1.2)
            errorMessage = "Kullanım Koşulları'nı kabul etmeniz gerekir."
            return
        }

        // ---- 2) PAKETİ HAZIRLA ----
        // 15 Kasım (yönetici kararı): kayıtta araç SORULMUYOR (ilk amaç kullanıcıyı kaydetmek) → vehicles nil.
        //   Araçlar giriş yaptıktan sonra Araçlarım'dan eklenir (Views/VehiclesView); teklif vermek için en az bir araç gerekir (sunucu kuralı).
        let body = RegisterCarrierRequest(fullName: name, email: mail, password: password, phone: tel,
                                          vehicles: nil, kvkkAccepted: kvkkAccepted, termsAccepted: termsAccepted)

        // ---- 3) GÖNDER ----
        isLoading = true
        errorMessage = nil
        isSuccess = false
        defer { isLoading = false } // defer [SWIFT]: fonksiyondan çıkarken çalışacak kod
        do {
            _ = try await auth.registerCarrier(body) // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
            isSuccess = true
        } catch {
            if let message = error.userMessage { errorMessage = message }
        }
    }
}
