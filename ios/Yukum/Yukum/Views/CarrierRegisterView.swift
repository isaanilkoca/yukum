//
//  CarrierRegisterView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 28.10.2026.
//

import SwiftUI // import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: CarrierRegisterView (Taşımacı kaydı) ──────────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ Kişi alanları + KVKK     →  viewModel.fullName, email, phone, password, kvkkAccepted ($ bağlar)  →  (register() okur)  →  -  →  RegisterCarrierRequest
// │ Araç Picker + kapasite + plaka  →  viewModel.vehicleType, capacityKg, plateNumber  →  (register() VehicleRequest'e çevirir)  →  -  →  VehicleType (seçenekler), VehicleRequest
// │ Kayıt Ol düğmesi         →  viewModel.register()                →  AuthService.registerCarrier()   →  POST /api/v1/auth/register/carrier →  RegisterCarrierRequest ([VehicleRequest]) → RegisterResponse
// │ Hata / başarı yazıları   →  viewModel.errorMessage, isSuccess   →  (sunucunun Türkçe mesajı)       →  -                                →  APIErrorResponse
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: Taşımacı kayıt formu. Akış: alanları doldur → kontrol et → pakete koy → AuthService ile API'ye gönder → sonucu göster
// MVVM: bu dosya yalnız GÖRÜNÜM. Alanlar, doğrulama, araç ve kayıt paketlerini hazırlama, gönderme ViewModels/CarrierRegisterViewModel.swift'te.
// [BİZİM] = adı biz koyduk | [SWIFT] = Swift/SwiftUI'nin hazır kodu
// BAĞLANTI: Views/RoleSelectionView.swift'teki "Taşımacı" NavigationLink'i bu ekranı açar | gönderen: Services/AuthService.swift → registerCarrier

struct CarrierRegisterView: View {

    // viewModel: formun durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar (yazılan alanlar kaybolmaz)
    @State private var viewModel = CarrierRegisterViewModel() // @State [SWIFT]: ekranın hafızası: değişince ekran yenilenir

    var body: some View {

        // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile İKİ YÖNLÜ bağ kurar (TextField/Picker/Toggle doğrudan ViewModel'e yazsın diye)
        @Bindable var viewModel = viewModel

        GeometryReader { geo in // geo: ekranın ölçüsü | ScrollView içeriğini ortalamak için kullanıyoruz | GeometryReader [SWIFT]: ekranın ölçüsünü verir
            ScrollView { // klavye açılınca/uzun formda kaydırma | ScrollView [SWIFT]: kaydırılabilir alan
                VStack(spacing: 31) { // elemanları alt alta dizer | VStack [SWIFT]: elemanları alt alta dizer

                    Text("Taşımacı Kaydı").font(.largeTitle).bold() // .font [SWIFT]: yazı boyutu/stili | .bold [SWIFT]: yazıyı kalın yapar

                    // TextField(ipucu, text: $değişken) | $: iki yönlü bağ, yazılan yazı doğrudan ViewModel'deki değişkene gider
                    TextField("Ad - Soyad / Firma", text: $viewModel.fullName).textFieldStyle(.roundedBorder) // .textFieldStyle [SWIFT]: yazı kutusu stili

                    TextField("E-posta", text: $viewModel.email).textInputAutocapitalization(.never).keyboardType(.emailAddress).textFieldStyle(.roundedBorder) // .never: baş harf büyümesin | .emailAddress: @ kolay çıkan klavye | .keyboardType [SWIFT]: klavye türü | .textInputAutocapitalization [SWIFT]: otomatik büyük harf ayarı

                    TextField("Telefon", text: $viewModel.phone).keyboardType(.phonePad).textFieldStyle(.roundedBorder) // .phonePad: telefon klavyesi

                    SecureField("Şifre", text: $viewModel.password).textFieldStyle(.roundedBorder) // yazılan nokta nokta görünür | SecureField [SWIFT]: şifre kutusu (yazılan nokta nokta görünür)

                    // Picker: açılır liste | selection: $viewModel.vehicleType → seçilen değer ViewModel'deki değişkene yazılır
                    Picker("Araç Türü", selection: $viewModel.vehicleType) {
                        Text("Araç Türünü Seçiniz").tag("") // tag(""): boş değerle eşleşir → hiçbir şey seçilmemişken bu yazı görünür | .tag [SWIFT]: Picker seçeneğinin değeri
                        ForEach(VehicleType.allCases) { type in // VehicleType.allCases: bütün araç türleri (Models/Vehicles/VehicleType.swift) | ilan formuyla AYNI tek kaynak | ForEach [SWIFT]: listedeki her eleman için bir satır çizer
                            Text(type.title).tag(type.rawValue) // type.title: ekranda görünen Türkçe ad | type.rawValue = tag: seçilince değişkene yazılacak API değeri
                        }
                    }.pickerStyle(.menu) // açılır menü görünümü | .pickerStyle [SWIFT]: seçici görünüm stili

                    TextField("Kapasite (kg)", text: $viewModel.capacityKg).keyboardType(.numberPad).textFieldStyle(.roundedBorder) // .numberPad: sadece rakam klavyesi

                    TextField("Plaka (isteğe bağlı)", text: $viewModel.plateNumber).textFieldStyle(.roundedBorder)

                    Toggle("KVKK Metnini onaylıyorum", isOn: $viewModel.kvkkAccepted) // aç/kapa anahtarı; $ ile true/false ViewModel'e yazılır

                    // if let errorMessage: doluysa içini çıkarıp göster, nil ise bu satır hiç çizilmez
                    if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundColor(.red) } // .foregroundColor [SWIFT]: yazı rengi

                    // isSuccess true olunca yeşil başarı yazısı çıkar
                    if viewModel.isSuccess { Text("Başarıyla kayıt oldunuz. Şimdi giriş yapabilirsiniz.").foregroundColor(.green) }

                    // Düğme yalnız TETİKLEYİCİ: kontroller, araç/kayıt paketlerini hazırlama ve gönderme ViewModel.register()'da
                    Button("Kayıt Ol") { Task { await viewModel.register() } } // ⮕ CarrierRegisterViewModel.register() → AuthService.registerCarrier(RegisterCarrierRequest) → POST /api/v1/auth/register/carrier | await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder) | Task [SWIFT]: arka planda çalışan iş: normal koddan await kullanabilmeyi sağlar | Button [SWIFT]: dokununca kod çalıştıran düğme
                        .buttonStyle(.borderedProminent).disabled(viewModel.isLoading) // .disabled: isLoading true iken basılamaz (çift tıklama olmasın) | .disabled [SWIFT]: koşul doğruysa basılamaz/kilitli | .buttonStyle [SWIFT]: düğme görünüm stili
                }.padding() // .padding [SWIFT]: etrafında boşluk bırakır
                    .frame(minHeight: geo.size.height) // en az ekran boyu: içerik ortada durur, uzunsa kaydırılır | .frame [SWIFT]: görünüm boyutu
            }
        }
    }
}

#Preview { // #Preview [SWIFT]: Xcode'da canlı önizleme (uygulamayı etkilemez)
    CarrierRegisterView()
}
