//
//  CarrierRegisterView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 28.10.2026.
//

import SwiftUI // import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: CarrierRegisterView (Taşımacı kayıt ALANLARI) ─────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ Kişi alanları + KVKK     →  viewModel.fullName, email, phone, password, kvkkAccepted ($ bağlar)  →  (register() okur)  →  -  →  RegisterCarrierRequest
// │ Kayıt ol düğmesi         →  viewModel.register()                →  AuthService.registerCarrier()   →  POST /api/v1/auth/register/carrier →  RegisterCarrierRequest ([VehicleRequest]) → RegisterResponse
// │ Hata / başarı yazıları   →  viewModel.errorMessage, isSuccess   →  (sunucunun Türkçe mesajı)       →  -                                →  APIErrorResponse
// └──────────────────────────────────────────────────────────────────────

// BU GÖRÜNÜM: Taşımacı kayıt formunun ALANLARI. Akış: alanları doldur → kontrol et → pakete koy → AuthService ile API'ye gönder → sonucu göster
// 14 Kasım tasarımı: artık tam ekran değil; Views/RoleSelectionView (tek kayıt ekranı) kartının İÇİNDE çizilir (arka plan, başlık, kart orada).
//   Görünüm giriş ekranıyla aynı: LabeledInput, FormConsent, FormMessage, AccentButtonLabel ⮕ Design/FormStyle.swift
//   Kişi bilgileri ile araç bilgileri arasında küçük bir "Araç bilgileri" ara başlığı var (uzun formda nerede olduğun belli olsun).
// MVVM: bu dosya yalnız GÖRÜNÜM. Alanlar, doğrulama, araç ve kayıt paketlerini hazırlama, gönderme ViewModels/CarrierRegisterViewModel.swift'te (DEĞİŞMEDİ).
// [BİZİM] = adı biz koyduk | [SWIFT] = Swift/SwiftUI'nin hazır kodu
// BAĞLANTI: gönderen: Models/Services/AuthService.swift → registerCarrier
// ⮕ KULLANIM [CarrierRegisterView]: kullanır: RoleSelectionView › body (Taşımacı seçiliyken)
struct CarrierRegisterView: View {

    @Environment(\.colorScheme) private var colorScheme // [SWIFT] açık/koyu mod → ara başlık rengi
    // viewModel: formun durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar (yazılan alanlar kaybolmaz)
    // ⮕ KULLANIM [viewModel]: bağlar(okur+yazar): CarrierRegisterView › body | okur: CarrierRegisterView › body
    @State private var viewModel = CarrierRegisterViewModel() // @State [SWIFT]: ekranın hafızası: değişince ekran yenilenir
    // 15 Kasım: başarıda e-posta yukarı iletilir (RoleSelectionView giriş ekranına döndürür)
    var onRegistered: (String) -> Void = { _ in }

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View {

        // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile İKİ YÖNLÜ bağ kurar (TextField/Picker/Toggle doğrudan ViewModel'e yazsın diye)
        @Bindable var viewModel = viewModel
        let palette = Palette(isDark: colorScheme == .dark)

        VStack(alignment: .leading, spacing: 16) {
            // KİŞİ BİLGİLERİ | LabeledInput ⮕ Design/FormStyle.swift | $: iki yönlü bağ
            LabeledInput(label: "Ad Soyad / Firma", systemImage: "person.fill") {
                TextField("Adınız ya da firma adınız", text: $viewModel.fullName).textContentType(.name)
            }
            LabeledInput(label: "E-posta", systemImage: "envelope.fill") {
                TextField("E-posta adresiniz", text: $viewModel.email) // NOT: ipucuna örnek adres yazılmaz, iOS onu mavi bağlantı gibi boyuyor
                    .textInputAutocapitalization(.never).keyboardType(.emailAddress).textContentType(.emailAddress)
            }
            LabeledInput(label: "Telefon", systemImage: "phone.fill") {
                TextField("05xx xxx xx xx", text: $viewModel.phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
            }
            LabeledInput(label: "Şifre", systemImage: "lock.fill") {
                SecureField("En az 8 karakter", text: $viewModel.password).textContentType(.newPassword)
            }

            // ARAÇ BİLGİLERİ KALDIRILDI (15 Kasım, yönetici: "ilk amaç kullanıcıyı kaydetmek; içerde araç kaydetme sayfası olmalı")
            //   → araçlar giriş yaptıktan sonra Araçlarım'dan eklenir (Views/VehiclesView). Kullanıcı bunu bilsin diye kısa not:
            Label("Araçlarını giriş yaptıktan sonra Araçlarım'dan ekleyebilirsin. Teklif vermek için en az bir araç gerekir.", systemImage: "truck.box.fill")
                .font(.footnote).foregroundStyle(palette.label.opacity(0.8))

            FormConsent(isOn: $viewModel.kvkkAccepted) // KVKK onayı + "metni oku" ⮕ Design/FormStyle.swift
            FormConsent(isOn: $viewModel.termsAccepted, document: .terms) // 15 Kasım: Kullanım Koşulları (ayrı kutu) ⮕ Views/TermsView

            if let errorMessage = viewModel.errorMessage { FormMessage(text: errorMessage, isError: true) }
            if viewModel.isSuccess { FormMessage(text: "Başarıyla kayıt oldunuz. Şimdi giriş yapabilirsiniz.", isError: false) }

            // Düğme yalnız TETİKLEYİCİ: kontroller, araç/kayıt paketlerini hazırlama ve gönderme ViewModel.register()'da
            Button { Task { await viewModel.register() } } label: { AccentButtonLabel(title: "Kayıt ol", isLoading: viewModel.isLoading, loadingTitle: "Kaydediliyor…") } // ⮕ CarrierRegisterViewModel.register() → AuthService.registerCarrier → POST /api/v1/auth/register/carrier
                .disabled(viewModel.isLoading) // isLoading true iken basılamaz (çift tıklama olmasın)
                .padding(.top, 4)
        }
        .onChange(of: viewModel.isSuccess) { _, ok in if ok { onRegistered(viewModel.email.trimmingCharacters(in: .whitespaces)) } } // 15 Kasım: başarı → RoleSelectionView giriş ekranına döndürür
    }
}

#Preview { // #Preview [SWIFT]: Xcode'da canlı önizleme (uygulamayı etkilemez)
    NavigationStack { RoleSelectionView(initialRole: .carrier) }
}
