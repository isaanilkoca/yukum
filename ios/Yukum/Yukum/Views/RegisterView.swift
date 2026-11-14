//
//  RegisterView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: RegisterView (Yük Veren kayıt ALANLARI) ───────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ Form alanları + KVKK     →  viewModel.fullName, email, phone, password, companyName, kvkkAccepted ($ bağlar)  →  (register() okur)  →  -  →  RegisterRequest
// │ Kayıt ol düğmesi         →  viewModel.register()                →  AuthService.register()          →  POST /api/v1/auth/register/shipper →  RegisterRequest → RegisterResponse
// │ Hata / başarı yazıları   →  viewModel.errorMessage, isSuccess   →  (sunucunun Türkçe mesajı)       →  -                                →  APIErrorResponse
// └──────────────────────────────────────────────────────────────────────

// BU GÖRÜNÜM: Yük Veren kayıt formunun ALANLARI. Akış: alanları doldur → kontrol et → pakete koy → AuthService ile API'ye gönder → sonucu göster
// 14 Kasım tasarımı: artık tam ekran değil; Views/RoleSelectionView (tek kayıt ekranı) kartının İÇİNDE çizilir (arka plan, başlık, kart orada).
//   Görünüm giriş ekranıyla aynı: LabeledInput (etiketli, simgeli kutu), FormConsent (KVKK), FormMessage (hata/başarı), AccentButtonLabel (turuncu düğme)
//   ⮕ hepsi Design/FormStyle.swift.
// MVVM: bu dosya yalnız GÖRÜNÜM. Alanlar, doğrulama, paket hazırlama, gönderme ViewModels/RegisterViewModel.swift'te (DEĞİŞMEDİ).
// BAĞLANTI: Paket kalıbı: Models/Auth/RegisterRequest.swift | gönderen: Models/Services/AuthService.swift → register
// ⮕ KULLANIM [RegisterView]: kullanır: RoleSelectionView › body (Yük Veren seçiliyken)
struct RegisterView: View { // RegisterView [BİZİM] ad | View [SWIFT]: bu bir ekran parçası

    // viewModel: formun durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar (yazılan alanlar kaybolmaz)
    // ⮕ KULLANIM [viewModel]: bağlar(okur+yazar): RegisterView › body | okur: RegisterView › body
    @State private var viewModel = RegisterViewModel() // @State [SWIFT]: ekranın hafızası: değişince ekran yenilenir

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View {

        // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile İKİ YÖNLÜ bağ kurar (TextField/Toggle doğrudan ViewModel'e yazsın diye)
        @Bindable var viewModel = viewModel

        // Kartın içinde alt alta | spacing: FormCard ile aynı aralık
        VStack(alignment: .leading, spacing: 16) {
            // LabeledInput(etiket, simge) { alan } ⮕ Design/FormStyle.swift | $ = iki yönlü bağ: yazılan doğrudan ViewModel'e gider
            LabeledInput(label: "Ad Soyad", systemImage: "person.fill") {
                TextField("Adınız ve soyadınız", text: $viewModel.fullName).textContentType(.name) // .textContentType [SWIFT]: klavye öneri/otomatik doldurma ipucu
            }
            LabeledInput(label: "E-posta", systemImage: "envelope.fill") {
                TextField("E-posta adresiniz", text: $viewModel.email) // NOT: ipucuna örnek adres yazılmaz, iOS onu mavi bağlantı gibi boyuyor
                    .textInputAutocapitalization(.never).keyboardType(.emailAddress).textContentType(.emailAddress) // .never: baş harf büyümesin
            }
            LabeledInput(label: "Telefon", systemImage: "phone.fill") {
                TextField("05xx xxx xx xx", text: $viewModel.phone).keyboardType(.phonePad).textContentType(.telephoneNumber) // .phonePad: telefon klavyesi
            }
            LabeledInput(label: "Şifre", systemImage: "lock.fill") {
                SecureField("En az 8 karakter", text: $viewModel.password).textContentType(.newPassword) // SecureField [SWIFT]: yazılan nokta nokta görünür
            }
            LabeledInput(label: "Firma adı (isteğe bağlı)", systemImage: "building.2.fill") {
                TextField("Firmanız varsa", text: $viewModel.companyName)
            }

            FormConsent(isOn: $viewModel.kvkkAccepted) // KVKK onayı + "metni oku" ⮕ Design/FormStyle.swift

            // Hata / başarı yazısı ⮕ Design/FormStyle.swift › FormMessage | errorMessage nil ise çizilmez
            if let errorMessage = viewModel.errorMessage { FormMessage(text: errorMessage, isError: true) }
            if viewModel.isSuccess { FormMessage(text: "Kayıt başarılı! Giriş yapabilirsiniz.", isError: false) }

            // Düğme yalnız TETİKLEYİCİ: kontroller, paket hazırlama ve gönderme ViewModel.register()'da | Task [SWIFT]: düğmede await kullanmamızı sağlar
            Button { Task { await viewModel.register() } } label: { AccentButtonLabel(title: "Kayıt ol", isLoading: viewModel.isLoading, loadingTitle: "Kaydediliyor…") } // ⮕ RegisterViewModel.register() → AuthService.register → POST /api/v1/auth/register/shipper
                .disabled(viewModel.isLoading) // isLoading true iken basılamaz (çift tıklama olmasın) | .disabled [SWIFT]
                .padding(.top, 4)
        }
    }
}

#Preview { // Xcode önizleme | #Preview [SWIFT]: Xcode'da canlı önizleme (uygulamayı etkilemez)
    NavigationStack { RoleSelectionView(initialRole: .shipper) }
}
