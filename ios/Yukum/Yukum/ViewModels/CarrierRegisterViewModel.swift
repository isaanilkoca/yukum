//
//  CarrierRegisterViewModel.swift
//  Yukum
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: CarrierRegisterViewModel ───────────────────────────────────
// │ EKRAN     : Views/CarrierRegisterView (@State private var viewModel) — Taşımacı kayıt formu; Views/RoleSelectionView açar
// │ SERVİS    : Services/Protocols/AuthServicing → AuthService.registerCarrier → POST /api/v1/auth/register/carrier
// │ MODEL     : RegisterCarrierRequest (içinde [VehicleRequest]) (giden), RegisterResponse (gelen), VehicleType (araç Picker'ı)
// │ AKIŞ      : Alanlar $viewModel ile doldurulur → "Kayıt Ol" → register(): doğrula → VehicleRequest → RegisterCarrierRequest → AuthService
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: Taşımacı kayıt formunun durumu ve mantığı (kişi alanları + tek araç, doğrulama, paket hazırlama, gönderme, sonuç)
// BAĞLANTI: Views/CarrierRegisterView.swift kullanır | servis: Services/AuthService.swift (AuthServicing sözleşmesi)
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
    // ⮕ KULLANIM [vehicleType]: okur: CarrierRegisterViewModel › register() | bağlar(okur+yazar): CarrierRegisterView › body | YAZAR: CarrierRegisterViewModelTests (test)
    var vehicleType = "" // seçili araç türü; API'ye bu metin gider (VehicleType.rawValue) | "" = henüz seçilmedi
    // ⮕ KULLANIM [capacityKg]: okur: CarrierRegisterViewModel › register(), CarrierRegisterViewModelTests (test) | bağlar(okur+yazar): CarrierRegisterView › body | YAZAR: CarrierRegisterViewModelTests (test)
    var capacityKg = "" // TextField yazı tuttuğu için String; göndermeden önce sayıya çevrilir
    // ⮕ KULLANIM [plateNumber]: okur: CarrierRegisterViewModel › register(), CarrierRegisterViewModelTests (test) | bağlar(okur+yazar): CarrierRegisterView › body | YAZAR: CarrierRegisterViewModelTests (test)
    var plateNumber = "" // plaka, isteğe bağlı
    // ⮕ KULLANIM [kvkkAccepted]: okur: CarrierRegisterViewModel › register() | bağlar(okur+yazar): CarrierRegisterView › body | YAZAR: CarrierRegisterViewModelTests (test)
    var kvkkAccepted = false
    // ⮕ ZİNCİR: Views/CarrierRegisterView: kırmızı hata yazısı
    // ⮕ KULLANIM [errorMessage]: YAZAR: CarrierRegisterViewModel › register() | okur: CarrierRegisterViewModelTests (test)
    var errorMessage: String?
    // ⮕ ZİNCİR: Views/CarrierRegisterView: "Kayıt Ol" düğmesi .disabled(viewModel.isLoading)
    // ⮕ KULLANIM [isLoading]: YAZAR: CarrierRegisterViewModel › register() | okur: CarrierRegisterView › body
    var isLoading = false
    // ⮕ ZİNCİR: Views/CarrierRegisterView: true olunca yeşil başarı yazısı
    // ⮕ KULLANIM [isSuccess]: YAZAR: CarrierRegisterViewModel › register() | okur: CarrierRegisterView › body, CarrierRegisterViewModelTests (test)
    var isSuccess = false

    // GEÇİCİ BORÇ: merkez il seçimi henüz yok → şimdilik sabit İstanbul (34)
    // ⮕ KULLANIM [defaultCityId]: okur: CarrierRegisterViewModelTests (test)
    static let defaultCityId = 34 // static [SWIFT]: türün kendisine ait (örnek üretmeden erişilir)

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
        guard !vehicleType.isEmpty else { // Picker'da hâlâ "Araç Türünü Seçiniz" duruyor
            errorMessage = "Araç türünü seçiniz !"
            return
        }
        guard let capacity = Int(capacityKg) else { // Int("24000") → 24000, Int("abc") → nil
            errorMessage = "Kapasite sayı olmalı."
            return
        }
        guard capacity > 0 else {
            errorMessage = "Kapasite sıfırdan büyük olmalı."
            return
        }
        guard kvkkAccepted else {
            errorMessage = "KVKK metnini onaylamanız gerekir."
            return
        }

        // ---- 2) PAKETİ HAZIRLA ----
        // API'ye "ekranı" göndermeyiz, yalnız bilgileri: önce araç paketi (VehicleRequest), sonra tüm kayıt paketi (içine araç listesi konur)
        let vehicle = VehicleRequest(type: vehicleType,
                                     plateNumber: plateNumber.isEmpty ? nil : plateNumber, // boşsa nil: JSON'a hiç yazılmaz
                                     capacityKg: capacity)
        let body = RegisterCarrierRequest(fullName: name, email: mail, password: password, phone: tel,
                                          homeCityId: Self.defaultCityId, vehicles: [vehicle], kvkkAccepted: kvkkAccepted)

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
