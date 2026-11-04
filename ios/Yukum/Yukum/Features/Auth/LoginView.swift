//
//  LoginView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: LoginView (giriş) ─────────────────────────────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ E-posta/Telefon + Şifre  →  viewModel.emailOrPhone, password ($ bağ)  →  (login() okur)            →  -                                →  LoginRequest
// │ Giriş yap düğmesi        →  viewModel.login()                   →  AuthService.login()             →  POST /api/v1/auth/login          →  LoginRequest → LoginResponse
// │ Açılışta otomatik giriş  →  viewModel.restoreSession()          →  AuthSession.restore()           →  POST /api/v1/auth/refresh        →  LoginResponse → LoginUser
// │ Hata yazısı              →  viewModel.errorMessage              →  APIError.userMessage            →  (sunucu Türkçe mesajı)           →  APIErrorResponse
// │ Ana sayfayı açma         →  viewModel.loggedInUser (dolunca)    →  fullScreenCover → HomeView(user:)  →  -                             →  LoginUser
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: giriş ekranı (uygulamanın ilk ekranı). Akış: alanları doldur → kontrol et → AuthService.login → HomeView
// MVVM: bu dosya yalnız GÖRÜNÜM. Alanlar, doğrulama, giriş isteği, otomatik giriş, hata Features/Auth/LoginViewModel.swift'te.
// BAĞLANTI: ContentView.swift bu ekranı açar | "Kayıt ol" → RoleSelectionView.swift | giriş başarılı → HomeView.swift
//           Paket kalıbı: Models/Auth/ | gönderen: Features/Auth/AuthService.swift → login | jetonlar: Core/Networking/AuthSession.swift
// ⮕ KULLANIM [LoginView]: kullanır: ContentView › body
struct LoginView: View { // LoginView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // viewModel: ekranın durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar
    // ⮕ KULLANIM [viewModel]: bağlar(okur+yazar): LoginView › body | okur: LoginView › body
    @State private var viewModel = LoginViewModel() // @State [SWIFT]: ekranın hafızası: değişince ekran yenilenir

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View { // ekranın içeriği

        // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile İKİ YÖNLÜ bağ kurar (TextField doğrudan ViewModel'e yazsın diye)
        @Bindable var viewModel = viewModel

        NavigationStack { // NavigationStack [SWIFT]: ekranlar arası geçiş + geri oku yönetir | "Kayıt ol" NavigationLink'i bunun içinde çalışır
            VStack(spacing: 40) { // elemanları alt alta dizer | VStack [SWIFT]: elemanları alt alta dizer

                Text("Yüküm").font(.largeTitle).bold() // başlık | .font [SWIFT]: yazı boyutu/stili | .bold [SWIFT]: yazıyı kalın yapar

                // $ = iki yönlü bağ: yazılan yazı doğrudan ViewModel'deki değişkene gider | .never: baş harf büyümesin | .emailAddress: @ kolay çıkan klavye
                TextField("Email veya Telefon", text: $viewModel.emailOrPhone).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).keyboardType(.emailAddress) // ⮕ LoginViewModel.emailOrPhone | .textFieldStyle [SWIFT]: yazı kutusu stili | .keyboardType [SWIFT]: klavye türü | .textInputAutocapitalization [SWIFT]: otomatik büyük harf ayarı

                SecureField("Şifre", text: $viewModel.password).textFieldStyle(.roundedBorder) // SecureField [SWIFT]: yazılan nokta nokta görünür

                if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundColor(.red) } // if let: doluysa kırmızı yaz, nil ise çizilmez | .foregroundColor [SWIFT]: yazı rengi

                HStack(spacing: 50) { // yan yana iki eleman | HStack [SWIFT]: elemanları yan yana dizer

                    // Button [SWIFT]: tıklanınca süslü parantezdeki kod çalışır | Task [SWIFT]: düğmede await (bekleme) kullanmamızı sağlar; ekran donmaz
                    // kontrol, paket hazırlama ve istek ViewModel.login()'de | sonuç: başarıda viewModel.loggedInUser dolar, hatada errorMessage dolar
                    Button("Giriş yap") { Task { await viewModel.login() } } // ⮕ LoginViewModel.login() → AuthService.login → POST /api/v1/auth/login
                        .disabled(viewModel.isLoading) // isLoading true iken basılamaz (çift tıklama olmasın) | .disabled [SWIFT]: koşul doğruysa basılamaz/kilitli

                    NavigationLink("Kayıt ol") { // NavigationLink [SWIFT]: kendisi düğme, basınca süslü parantezdeki ekrana geçer (Button içine konmaz)
                        RoleSelectionView() // Features/Auth/RoleSelectionView.swift → Yük Veren / Taşımacı seçimi
                    }

                }.padding() // .padding [SWIFT]: etrafında boşluk bırakır

            }.padding()
        }

        // OTOMATİK GİRİŞ | .task [SWIFT]: ekran açılınca bir kez çalışır
        // Keychain'de yenileme jetonu varsa sunucudan yeni jeton alınır; başarılıysa kullanıcı şifre yazmadan doğrudan ana sayfaya girer (loggedInUser dolunca fullScreenCover açılır)
        // Sunucu "oturum geçersiz" derse jeton silinir ve giriş formu görünür | internet yoksa jeton SİLİNMEZ, form görünür, kullanıcı sonra tekrar dener | BAĞLANTI: ViewModel.restoreSession → Core/Networking/AuthSession.swift → restore
        .task { await viewModel.restoreSession() } // ⮕ LoginViewModel.restoreSession() → AuthSession.restore() (Keychain'deki yenileme jetonuyla)
        // overlay [SWIFT]: ekranın ÜSTÜNE katman koyar | oturum aranırken giriş formunun üstünü örter ve dönen çark gösterir (form bir anlığına yanıp sönmesin)
        .overlay { // .overlay [SWIFT]: görünümün üstüne katman koyar
            if viewModel.isRestoring {
                ZStack { Color(.systemBackground); ProgressView("Oturum açılıyor...") } // ZStack: üst üste dizer | .systemBackground: açık/koyu moda uyan zemin rengi | ZStack [SWIFT]: elemanları üst üste dizer | ProgressView [SWIFT]: dönen yükleme çarkı | Color [SWIFT]: renk
            }
        }
        // BAĞLANTI: loggedInUser giriş başarılı olunca dolar → dolunca HomeView tam ekran açılır.
        // HomeView'daki "Çıkış Yap" dismiss() ile bu ekranı kapatır → loggedInUser tekrar nil olur → giriş ekranına dönülür.
        // item: Identifiable ister, LoginUser'a bu yüzden Identifiable eklendi (Models/Auth/).
        .fullScreenCover(item: $viewModel.loggedInUser) { user in // [SWIFT]: loggedInUser dolunca tam ekran açar, nil olunca kapatır | $ = bağ | user: dolan kullanıcı (adı bizim) | ⮕ LoginViewModel.loggedInUser (LoginUser) dolunca HomeView açılır | .fullScreenCover [SWIFT]: tam ekran açılan ekran
            HomeView(user: user) // Features/Listings/HomeView.swift'e kullanıcıyı veriyoruz
        }
    }
}

#Preview { // Xcode önizleme | #Preview [SWIFT]: Xcode'da canlı önizleme (uygulamayı etkilemez)
    LoginView()
}
