//
//  RegisterViewModel.swift
//  Yukum
//

import Foundation
import Observation

// ┌─ BAĞLANTI HARİTASI: RegisterViewModel ───────────────────────────────────────────
// │ EKRAN     : Views/RegisterView (@State private var viewModel) — Yük Veren kayıt formu; Views/RoleSelectionView açar
// │ SERVİS    : Services/Protocols/AuthServicing → AuthService.register → POST /api/v1/auth/register/shipper
// │ MODEL     : RegisterRequest (giden), RegisterResponse (gelen)
// │ AKIŞ      : Alanlar $viewModel ile doldurulur → "Kayıt Ol" → register(): doğrula → RegisterRequest → AuthService → isSuccess / errorMessage
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: Yük Veren kayıt formunun durumu ve mantığı (alanlar, doğrulama, paket hazırlama, gönderme, sonuç)
// BAĞLANTI: Views/RegisterView.swift kullanır | servis: Services/AuthService.swift (AuthServicing sözleşmesi)
@Observable
final class RegisterViewModel {

    private let auth: AuthServicing

    // ⮕ ZİNCİR: Views/RegisterView: TextField'lar ve Toggle, $viewModel ile doğrudan buraya yazar | register() okur, RegisterRequest alanlarına koyar
    var fullName = "" // ad soyad
    var email = ""
    var phone = ""
    var password = ""
    var companyName = "" // firma adı, isteğe bağlı (boşsa nil gider)
    var kvkkAccepted = false // KVKK Toggle'ı
    // ⮕ ZİNCİR: Views/RegisterView: kırmızı hata yazısı (doğrulama mesajı ya da sunucunun Türkçe mesajı)
    var errorMessage: String?
    // ⮕ ZİNCİR: Views/RegisterView: "Kayıt Ol" düğmesi .disabled(viewModel.isLoading) — çift tıklamayı engeller
    var isLoading = false
    // ⮕ ZİNCİR: Views/RegisterView: true olunca yeşil "Kayıt başarılı" yazısı
    var isSuccess = false

    // GEÇİCİ BORÇ: kayıtta il seçimi henüz yok, API il numarası ister → şimdilik sabit İstanbul (34). İl seçimi eklenince bu sabit kalkar.
    static let defaultCityId = 34

    init(auth: AuthServicing = AuthService()) { self.auth = auth }

    // register: "Kayıt Ol" düğmesi | ⮕ ZİNCİR: Views/RegisterView: Button { Task { await viewModel.register() } } → AuthService.register(RegisterRequest) → RegisterResponse (kullanılmaz, yalnız başarı)
    func register() async {
        // ---- 1) KONTROLLER: API'ye gitmeden ekranda yakalıyoruz ----
        let name = fullName.trimmingCharacters(in: .whitespaces), mail = email.trimmingCharacters(in: .whitespaces), tel = phone.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !mail.isEmpty, !tel.isEmpty, !password.isEmpty else {
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
        defer { isLoading = false } // düğme tekrar açılır
        do {
            _ = try await auth.register(body)
            isSuccess = true // yeşil mesaj
        } catch {
            if let message = error.userMessage { errorMessage = message } // API'nin Türkçe mesajı (örn. "Bu e-posta zaten kayıtlı.")
        }
    }
}
