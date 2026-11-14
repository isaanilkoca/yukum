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
// │ Araç Picker + kapasite + plaka  →  viewModel.vehicleType, capacityKg, plateNumber  →  (register() VehicleRequest'e çevirir)  →  -  →  VehicleType (seçenekler), VehicleRequest
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

            // ARAÇ BİLGİLERİ: ara başlık
            Text("Araç bilgileri")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.title)
                .padding(.top, 6)

            // Picker: açılır liste | selection: $viewModel.vehicleType → seçilen değer ViewModel'deki değişkene yazılır
            LabeledInput(label: "Araç türü", systemImage: "truck.box.fill") {
                Picker("Araç türü", selection: $viewModel.vehicleType) {
                    Text("Seçiniz").tag("") // tag(""): hiçbir şey seçilmemişken bu yazı görünür | .tag [SWIFT]: Picker seçeneğinin değeri
                    ForEach(VehicleType.allCases) { type in // ⮕ Models/Vehicles/VehicleType.swift (ilan formuyla aynı tek kaynak)
                        Text(type.title).tag(type.rawValue) // title: Türkçe ad | rawValue: API'ye giden değer
                    }
                }
                .pickerStyle(.menu) // açılır menü | .pickerStyle [SWIFT]
                .frame(maxWidth: .infinity, alignment: .leading) // kutunun içinde sola yaslı
            }
            LabeledInput(label: "Kapasite (kg)", systemImage: "scalemass.fill") {
                TextField("Örn. 12000", text: $viewModel.capacityKg).keyboardType(.numberPad) // .numberPad: yalnız rakam klavyesi
            }
            LabeledInput(label: "Plaka (isteğe bağlı)", systemImage: "number") {
                TextField("34 ABC 123", text: $viewModel.plateNumber).textInputAutocapitalization(.characters) // plaka büyük harf
            }

            FormConsent(isOn: $viewModel.kvkkAccepted) // KVKK onayı + "metni oku" ⮕ Design/FormStyle.swift

            if let errorMessage = viewModel.errorMessage { FormMessage(text: errorMessage, isError: true) }
            if viewModel.isSuccess { FormMessage(text: "Başarıyla kayıt oldunuz. Şimdi giriş yapabilirsiniz.", isError: false) }

            // Düğme yalnız TETİKLEYİCİ: kontroller, araç/kayıt paketlerini hazırlama ve gönderme ViewModel.register()'da
            Button { Task { await viewModel.register() } } label: { AccentButtonLabel(title: "Kayıt ol", isLoading: viewModel.isLoading, loadingTitle: "Kaydediliyor…") } // ⮕ CarrierRegisterViewModel.register() → AuthService.registerCarrier → POST /api/v1/auth/register/carrier
                .disabled(viewModel.isLoading) // isLoading true iken basılamaz (çift tıklama olmasın)
                .padding(.top, 4)
        }
    }
}

#Preview { // #Preview [SWIFT]: Xcode'da canlı önizleme (uygulamayı etkilemez)
    NavigationStack { RoleSelectionView(initialRole: .carrier) }
}
