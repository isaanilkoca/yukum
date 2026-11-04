//
//  LoginView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// BU EKRAN: giriş ekranı (uygulamanın ilk ekranı). Akış: alanları doldur → kontrol et → AuthService.login → HomeView
// MVVM: bu dosya yalnız GÖRÜNÜM. Alanlar, doğrulama, giriş isteği, otomatik giriş, hata ViewModel/LoginViewModel.swift'te.
// BAĞLANTI: ContentView.swift bu ekranı açar | "Kayıt ol" → RoleSelectionView.swift | giriş başarılı → HomeView.swift
//           Paket kalıbı: Network/LoginRequest.swift | gönderen: Network/AuthService.swift → login | jetonlar: Network/AuthSession.swift
struct LoginView: View { // LoginView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // viewModel: ekranın durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar
    @State private var viewModel = LoginViewModel()

    var body: some View { // ekranın içeriği

        // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile İKİ YÖNLÜ bağ kurar (TextField doğrudan ViewModel'e yazsın diye)
        @Bindable var viewModel = viewModel

        NavigationStack { // NavigationStack [SWIFT]: ekranlar arası geçiş + geri oku yönetir | "Kayıt ol" NavigationLink'i bunun içinde çalışır
            VStack(spacing: 40) { // elemanları alt alta dizer

                Text("Yüküm").font(.largeTitle).bold() // başlık

                // $ = iki yönlü bağ: yazılan yazı doğrudan ViewModel'deki değişkene gider | .never: baş harf büyümesin | .emailAddress: @ kolay çıkan klavye
                TextField("Email veya Telefon", text: $viewModel.emailOrPhone).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).keyboardType(.emailAddress)

                SecureField("Şifre", text: $viewModel.password).textFieldStyle(.roundedBorder) // SecureField [SWIFT]: yazılan nokta nokta görünür

                if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundColor(.red) } // if let: doluysa kırmızı yaz, nil ise çizilmez

                HStack(spacing: 50) { // yan yana iki eleman

                    // Button [SWIFT]: tıklanınca süslü parantezdeki kod çalışır | Task [SWIFT]: düğmede await (bekleme) kullanmamızı sağlar; ekran donmaz
                    // kontrol, paket hazırlama ve istek ViewModel.login()'de | sonuç: başarıda viewModel.loggedInUser dolar, hatada errorMessage dolar
                    Button("Giriş yap") { Task { await viewModel.login() } }
                        .disabled(viewModel.isLoading) // isLoading true iken basılamaz (çift tıklama olmasın)

                    NavigationLink("Kayıt ol") { // NavigationLink [SWIFT]: kendisi düğme, basınca süslü parantezdeki ekrana geçer (Button içine konmaz)
                        RoleSelectionView() // View/RoleSelectionView.swift → Yük Veren / Taşımacı seçimi
                    }

                }.padding()

            }.padding()
        }

        // OTOMATİK GİRİŞ | .task [SWIFT]: ekran açılınca bir kez çalışır
        // Keychain'de yenileme jetonu varsa sunucudan yeni jeton alınır; başarılıysa kullanıcı şifre yazmadan doğrudan ana sayfaya girer (loggedInUser dolunca fullScreenCover açılır)
        // Sunucu "oturum geçersiz" derse jeton silinir ve giriş formu görünür | internet yoksa jeton SİLİNMEZ, form görünür, kullanıcı sonra tekrar dener | BAĞLANTI: ViewModel.restoreSession → Network/AuthSession.swift → restore
        .task { await viewModel.restoreSession() }
        // overlay [SWIFT]: ekranın ÜSTÜNE katman koyar | oturum aranırken giriş formunun üstünü örter ve dönen çark gösterir (form bir anlığına yanıp sönmesin)
        .overlay {
            if viewModel.isRestoring {
                ZStack { Color(.systemBackground); ProgressView("Oturum açılıyor...") } // ZStack: üst üste dizer | .systemBackground: açık/koyu moda uyan zemin rengi
            }
        }
        // BAĞLANTI: loggedInUser giriş başarılı olunca dolar → dolunca HomeView tam ekran açılır.
        // HomeView'daki "Çıkış Yap" dismiss() ile bu ekranı kapatır → loggedInUser tekrar nil olur → giriş ekranına dönülür.
        // item: Identifiable ister, LoginUser'a bu yüzden Identifiable eklendi (Network/LoginRequest.swift).
        .fullScreenCover(item: $viewModel.loggedInUser) { user in // [SWIFT]: loggedInUser dolunca tam ekran açar, nil olunca kapatır | $ = bağ | user: dolan kullanıcı (adı bizim)
            HomeView(user: user) // View/HomeView.swift'e kullanıcıyı veriyoruz
        }
    }
}

#Preview { // Xcode önizleme
    LoginView()
}
