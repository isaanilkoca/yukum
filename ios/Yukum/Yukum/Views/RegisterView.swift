//
//  RegisterView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: RegisterView (Yük Veren kaydı) ────────────────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ Form alanları + KVKK     →  viewModel.fullName, email, phone, password, companyName, kvkkAccepted ($ bağlar)  →  (register() okur)  →  -  →  RegisterRequest
// │ Kayıt Ol düğmesi         →  viewModel.register()                →  AuthService.register()          →  POST /api/v1/auth/register/shipper →  RegisterRequest → RegisterResponse
// │ Hata / başarı yazıları   →  viewModel.errorMessage, isSuccess   →  (sunucunun Türkçe mesajı)       →  -                                →  APIErrorResponse
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: Yük Veren kayıt formu. Akış: alanları doldur → kontrol et → pakete koy → AuthService ile API'ye gönder → sonucu göster
// MVVM: bu dosya yalnız GÖRÜNÜM. Alanlar, doğrulama, paket hazırlama, gönderme ViewModels/RegisterViewModel.swift'te.
// BAĞLANTI: Views/RoleSelectionView.swift'teki "Yük Veren" NavigationLink'i bu ekranı açar.
//           Paket kalıbı: Models/Auth/RegisterRequest.swift | gönderen: Services/AuthService.swift → register
struct RegisterView: View { // RegisterView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // viewModel: formun durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar (yazılan alanlar kaybolmaz)
    @State private var viewModel = RegisterViewModel() // @State [SWIFT]: ekranın hafızası: değişince ekran yenilenir

    var body: some View { // ekranın içeriği

        // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile İKİ YÖNLÜ bağ kurar (TextField/Toggle doğrudan ViewModel'e yazsın diye)
        @Bindable var viewModel = viewModel

        GeometryReader { geo in // GeometryReader [SWIFT]: ekranın ölçüsünü verir | geo: bu ölçü (adı bizim)

            ScrollView { // ScrollView [SWIFT]: uzun formda kaydırma sağlar

                VStack(spacing: 24) { // elemanları alt alta dizer | VStack [SWIFT]: elemanları alt alta dizer

                    Text("Kayıt Ol ").font(.largeTitle).bold() // .font [SWIFT]: yazı boyutu/stili | .bold [SWIFT]: yazıyı kalın yapar

                    // TextField(ipucu, text: $değişken) | $ = iki yönlü bağ: yazılan yazı doğrudan ViewModel'deki değişkene gider
                    TextField("Ad - Soyad ", text: $viewModel.fullName).textFieldStyle(.roundedBorder) // .roundedBorder: yuvarlak çerçeveli kutu | .textFieldStyle [SWIFT]: yazı kutusu stili

                    TextField("E-posta ", text: $viewModel.email).textInputAutocapitalization(.never).keyboardType(.emailAddress).textFieldStyle(.roundedBorder) // .never: baş harf büyümesin | .emailAddress: @ kolay çıkan klavye | .keyboardType [SWIFT]: klavye türü | .textInputAutocapitalization [SWIFT]: otomatik büyük harf ayarı

                    TextField("Telefon ", text: $viewModel.phone).textInputAutocapitalization(.never).keyboardType(.phonePad).textFieldStyle(.roundedBorder) // .phonePad: telefon klavyesi

                    SecureField("Şifre", text: $viewModel.password).textFieldStyle(.roundedBorder) // SecureField [SWIFT]: yazılan nokta nokta görünür

                    TextField("Firma Adı (isteğe bağlı)", text: $viewModel.companyName).textFieldStyle(.roundedBorder)

                    Toggle("KVKK metnini onaylıyorum", isOn: $viewModel.kvkkAccepted) // Toggle [SWIFT]: aç/kapa anahtarı | isOn: durum ViewModel'e true/false yazılır

                    if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundColor(.red) } // if let: errorMessage doluysa içini çıkarıp göster, nil ise satır çizilmez | .foregroundColor [SWIFT]: yazı rengi

                    if viewModel.isSuccess { Text("Kayıt başarılı! Giriş yapabilirsiniz.").foregroundColor(.green) } // isSuccess true olunca görünür

                    // Düğme yalnız TETİKLEYİCİ: kontroller, paket hazırlama ve gönderme ViewModel.register()'da | Task [SWIFT]: düğmede await kullanmamızı sağlar; ekran donmaz
                    Button("Kayıt Ol") { Task { await viewModel.register() } } // ⮕ RegisterViewModel.register() → AuthService.register(RegisterRequest) → POST /api/v1/auth/register/shipper | Button [SWIFT]: dokununca kod çalıştıran düğme
                        .buttonStyle(.borderedProminent) // .buttonStyle [SWIFT]: düğme görünüm stili
                        .disabled(viewModel.isLoading) // .disabled: isLoading true iken basılamaz (çift tıklama olmasın) | .disabled [SWIFT]: koşul doğruysa basılamaz/kilitli

                }.padding().frame(minHeight: geo.size.height) // frame(minHeight:): en az ekran boyu → içerik ortada durur, uzunsa kaydırılır | .padding [SWIFT]: etrafında boşluk bırakır | .frame [SWIFT]: görünüm boyutu
            }
        }
    }
}

#Preview { // Xcode önizleme | #Preview [SWIFT]: Xcode'da canlı önizleme (uygulamayı etkilemez)
    RegisterView()
}
