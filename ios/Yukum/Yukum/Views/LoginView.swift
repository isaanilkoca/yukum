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
// │ Arka plan (animasyon)    →  (ViewModel yok)                      →  Design/TapedBoxBackground.swift: düşen koliler + ekran bantları | renkler: Design/DesignPalette.swift
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: giriş ekranı (uygulamanın ilk ekranı). Akış: alanları doldur → kontrol et → AuthService.login → HomeView
// MVVM: bu dosya yalnız GÖRÜNÜM. Alanlar, doğrulama, giriş isteği, otomatik giriş, hata ViewModels/LoginViewModel.swift'te.
// BAĞLANTI: ContentView.swift bu ekranı açar | "Kayıt ol" → RoleSelectionView.swift | giriş başarılı → HomeView.swift
//           Paket kalıbı: Models/Auth/ | gönderen: Models/Services/AuthService.swift → login | jetonlar: Models/Networking/AuthSession.swift
// ⮕ KULLANIM [LoginView]: kullanır: ContentView › body
struct LoginView: View { // LoginView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // viewModel: ekranın durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar
    // ⮕ KULLANIM [viewModel]: bağlar(okur+yazar): LoginView › body | okur: LoginView › body
    @State private var viewModel = LoginViewModel() // @State [SWIFT]: ekranın hafızası: değişince ekran yenilenir

    // colorScheme: telefon açık modda mı koyu modda mı | @Environment [SWIFT]: sistemin verdiği ortam bilgisini okur
    // ⮕ KULLANIM [colorScheme]: okur: LoginView › body (palette seçimi)
    @Environment(\.colorScheme) private var colorScheme
    @State private var homeShown = false // ana ekran üstte açık mı | true → arkadaki 3B giriş sahnesi kaldırılır (aşağıda ZStack)
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system // görünüm seçimi (⮕ Design/ThemeToggle.swift) | ana ekrana da uygulanır (aşağıda)

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View { // ekranın içeriği

        // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile İKİ YÖNLÜ bağ kurar (TextField doğrudan ViewModel'e yazsın diye)
        @Bindable var viewModel = viewModel

        // palette: tasarım renkleri (Design/DesignPalette.swift) | telefonun açık/koyu moduna göre seçilir
        let palette = Palette(isDark: colorScheme == .dark)

        NavigationStack { // NavigationStack [SWIFT]: ekranlar arası geçiş + geri oku yönetir | "Kayıt ol" NavigationLink'i bunun içinde çalışır
            // TASARIM (L): ekranın TAMAMININ arkasında koli sahnesi + bantlar durur; yazılar ve alanlar onun üstünde, ekrana yayılmıştır.
            // ZStack [SWIFT]: elemanları üst üste dizer (arkadan öne) → önce arka plan, sonra form.
            // Animasyonun tüm kodu Design/ klasöründe (rehber: Design/00_Rehber_Design.swift); bu ekran yalnız TapedBoxBackground()'u çağırır.
            // Alanların/düğmelerin bağlandığı yerler (viewModel.x, login()) DEĞİŞMEDİ; yalnız görünümleri değişti.
            ZStack {
            // NE ZAMAN ÇİZİLMEZ (13 Kasım gecikme düzeltmesi):
            //   1) isRestoring: otomatik giriş aranırken form zaten örtülü; oturum bulunursa bu sahne hiç görünmeden ana ekran açılır.
            //      Önceden yine de kuruluyordu → açılışta telefon iki 3B sahneyi (koliler + kamyon) AYNI ANDA hazırlıyordu.
            //   2) homeShown: ana ekran üstte açıkken giriş ekranı arkada canlı kalır (fullScreenCover onu kapatmaz) → sahne boşuna çizilir.
            // Çıkış yapınca homeShown false olur → sahne yeniden kurulur, koliler yeniden düşer (yeni giriş ekranı gibi).
            if !viewModel.isRestoring && !homeShown {
                TapedBoxBackground() // Design/TapedBoxBackground.swift → koliler düşer, durunca ekran bantlanır
                    // .id(colorScheme) [SWIFT]: değer değişince görünüm SIFIRDAN kurulur → görünüm (açık/koyu) değiştirilince 3B sahne
                    //   yeni renklerle yeniden kurulur, koliler yeniden düşer (3B malzemeler kurulurken bir kez seçilir, sonradan kendiliğinden değişmez)
                    .id(colorScheme)
            }

            VStack(spacing: 14) { // elemanları alt alta dizer | VStack [SWIFT]: elemanları alt alta dizer

                Spacer().frame(height: 36) // üstten sabit boşluk | Spacer [SWIFT]: boşluk

                Text("Yüküm") // başlık
                    .font(.system(size: 54, weight: .heavy, design: .rounded)) // .font [SWIFT]: yazı boyutu/stili | rounded: yuvarlak hatlı
                    .foregroundStyle(palette.title) // renk Design/DesignPalette.swift'ten (gece krem, gündüz koyu kahve)
                    .shadow(color: .black.opacity(palette.isDark ? 0.6 : 0), radius: 10) // bandın/kolinin üstünde okunaklı kalsın
                Text("Yükün yolda, aklın rahat.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(palette.title.opacity(0.75))

                Spacer() // esnek boşluk: başlık yukarıda, form kartı aşağıda kalır (ekran boyuna göre açılır)

                // FORM KARTI: opak kart arka planı (koliler, bantlar) tamamen keser → kullanıcı nereye ne yazacağını tek bakışta görür.
                // FormCard ve LabeledInput: Design/FormStyle.swift (yalnız GÖRÜNÜM; alanların kendisi ve bağları aşağıda, bu dosyada)
                FormCard {

                    // Hesap türü seçici: aynı e-posta/telefon hem Yük Veren hem Taşımacı olarak kayıtlı olabilir, hangisine girileceği buradan seçilir
                    // Picker [SWIFT]: seçim listesi | .pickerStyle(.segmented): yan yana iki parçalı anahtar | $viewModel.role: seçim doğrudan ViewModel'e yazılır
                    // ForEach(LoginRole.allCases): Models/Auth/LoginRole.swift'teki seçenekler | .tag: seçeneğin değeri
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Hesap türü").font(.footnote.weight(.semibold)).foregroundStyle(palette.label) // etiket: seçicinin ne olduğunu söyler
                        Picker("Hesap türü", selection: $viewModel.role) {
                            ForEach(LoginRole.allCases) { role in Text(role.title).tag(role) }
                        }
                        .pickerStyle(.segmented)
                    }

                    // $ = iki yönlü bağ: yazılan yazı doğrudan ViewModel'deki değişkene gider | .never: baş harf büyümesin | .emailAddress: @ kolay çıkan klavye
                    LabeledInput(label: "E-posta veya telefon", systemImage: "envelope.fill") {
                        TextField("E-posta ya da telefon numaranız", text: $viewModel.emailOrPhone).textInputAutocapitalization(.never).keyboardType(.emailAddress) // ⮕ LoginViewModel.emailOrPhone | .keyboardType [SWIFT]: klavye türü | .textInputAutocapitalization [SWIFT]: otomatik büyük harf ayarı
                    }

                    LabeledInput(label: "Şifre", systemImage: "lock.fill") {
                        SecureField("Şifreniz", text: $viewModel.password) // SecureField [SWIFT]: yazılan nokta nokta görünür | ⮕ LoginViewModel.password
                    }

                    // if let: doluysa göster, nil ise çizilmez | simge + kırmızı yazı: hata olduğu renk görmeyen kullanıcıya da belli olsun
                    if let errorMessage = viewModel.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill") // Label [SWIFT]: simge + yazı
                            .font(.footnote.weight(.semibold)).foregroundStyle(.red) // .foregroundStyle [SWIFT]: yazı rengi
                    }

                    // Button [SWIFT]: tıklanınca ilk süslü parantezdeki kod çalışır; label: düğmenin görünümü | Task [SWIFT]: düğmede await (bekleme) kullanmamızı sağlar; ekran donmaz
                    // kontrol, paket hazırlama ve istek ViewModel.login()'de | sonuç: başarıda viewModel.loggedInUser dolar, hatada errorMessage dolar
                    Button { Task { await viewModel.login() } } label: { // ⮕ LoginViewModel.login() → AuthService.login → POST /api/v1/auth/login
                        Text("Giriş yap")
                            .font(.headline)
                            .foregroundStyle(palette.buttonText)
                            .frame(maxWidth: .infinity) // .frame(maxWidth: .infinity) [SWIFT]: yatayda tüm genişliği kapla
                            .frame(height: 54)
                            .background(palette.accent, in: .rect(cornerRadius: 14)) // koli bandı turuncusu (DesignPalette.accent)
                    }
                    .disabled(viewModel.isLoading) // isLoading true iken basılamaz (çift tıklama olmasın) | .disabled [SWIFT]: koşul doğruysa basılamaz/kilitli
                    .padding(.top, 4)

                    NavigationLink { // NavigationLink [SWIFT]: kendisi düğme, basınca ilk süslü parantezdeki ekrana geçer (Button içine konmaz) | label: görünümü
                        RoleSelectionView(initialRole: viewModel.role) // Views/RoleSelectionView.swift → TEK kayıt ekranı | girişte seçili hesap türüyle açılır (14 Kasım)
                    } label: {
                        Text("Hesabın yok mu? **Kayıt ol**") // ** ** [SWIFT]: Markdown kalın yazı
                            .font(.subheadline)
                            .foregroundStyle(palette.label)
                            .frame(maxWidth: .infinity) // kartın ortasına hizala
                    }
                }

                Spacer() // alttaki esnek boşluk: üstteki Spacer ile birlikte kartı ekranın ortasına doğru taşır (kart en alta yapışmaz)
                    .frame(maxHeight: 110) // en fazla 110 nokta açılır → kart tam ortada değil, ortanın biraz altında durur

            }
            .padding(.horizontal, 20) // .padding [SWIFT]: etrafında boşluk bırakır
            .padding(.bottom, 12)
            } // ZStack sonu
            // GÖRÜNÜM DÜĞMESİ (Sistem / Açık / Koyu): sağ üst köşe | .overlay [SWIFT]: ekranın üstüne katman | ⮕ Design/ThemeToggle.swift
            .overlay(alignment: .topTrailing) {
                ThemeToggle()
                    .font(.title3)
                    .foregroundStyle(palette.title)
                    .frame(width: 40, height: 40)
                    .background(palette.cardSurface.opacity(0.55), in: Circle()) // bantların üstünde de seçilsin diye yarı saydam zemin
                    .padding(.trailing, 16)
                    .padding(.top, 4)
            }
        }

        // OTOMATİK GİRİŞ | .task [SWIFT]: ekran açılınca bir kez çalışır
        // Keychain'de yenileme jetonu varsa sunucudan yeni jeton alınır; başarılıysa kullanıcı şifre yazmadan doğrudan ana sayfaya girer (loggedInUser dolunca fullScreenCover açılır)
        // Sunucu "oturum geçersiz" derse jeton silinir ve giriş formu görünür | internet yoksa jeton SİLİNMEZ, form görünür, kullanıcı sonra tekrar dener | BAĞLANTI: ViewModel.restoreSession → Models/Networking/AuthSession.swift → restore
        .task { await viewModel.restoreSession() } // ⮕ LoginViewModel.restoreSession() → AuthSession.restore() (Keychain'deki yenileme jetonuyla)
        // DORSE MODELİNİ ÖNCEDEN YÜKLE (13 Kasım gecikme düzeltmesi): model iPhone 11'de ~4 sn'de yükleniyor; kullanıcı şifre yazarken arka planda biter
        //   → Yük Veren ana ekranında dorse hemen gelir. Yalnız son seçilen tür Yük Veren ise (Taşımacı ekranında dorse yok, boşuna yüklenmesin).
        // ⮕ Design/TruckLoadView.swift › TruckModel.preload
        .task { if viewModel.role == .shipper { TruckModel.preload() } }
        // overlay [SWIFT]: ekranın ÜSTÜNE katman koyar | oturum aranırken giriş formunun üstünü örter ve dönen çark gösterir (form bir anlığına yanıp sönmesin)
        .overlay { // .overlay [SWIFT]: görünümün üstüne katman koyar
            if viewModel.isRestoring {
                ZStack { Color(.systemBackground); ProgressView("Oturum açılıyor...") } // ZStack: üst üste dizer | .systemBackground: açık/koyu moda uyan zemin rengi | ZStack [SWIFT]: elemanları üst üste dizer | ProgressView [SWIFT]: dönen yükleme çarkı | Color [SWIFT]: renk
            }
        }
        // BAĞLANTI: loggedInUser giriş başarılı olunca dolar → dolunca HomeView tam ekran açılır.
        // HomeView'daki "Çıkış Yap" dismiss() ile bu ekranı kapatır → loggedInUser tekrar nil olur → giriş ekranına dönülür.
        // item: Identifiable ister, LoginUser'a bu yüzden Identifiable eklendi (Models/Auth/).
        // onDismiss [SWIFT]: tam ekran kapanınca (çıkış) çalışır → giriş sahnesi geri gelir
        .fullScreenCover(item: $viewModel.loggedInUser, onDismiss: { homeShown = false }) { user in // [SWIFT]: loggedInUser dolunca tam ekran açar, nil olunca kapatır | $ = bağ | user: dolan kullanıcı (adı bizim) | ⮕ LoginViewModel.loggedInUser (LoginUser) dolunca HomeView açılır | .fullScreenCover [SWIFT]: tam ekran açılan ekran
            HomeView(user: user) // Views/HomeView.swift'e kullanıcıyı veriyoruz
                // GÖRÜNÜM AYARI ana ekrana da (14 Kasım hatası: ana ekranda düğme çalışmıyordu).
                // NEDEN: tam ekran açılan sayfa (fullScreenCover) ayrı bir sunum katmanıdır; YukumApp'teki .preferredColorScheme ona geçmiyor.
                //   Aynı ayarı burada da veriyoruz → ana ekrandaki ve girişteki düğme aynı anda, her yerde çalışır.
                .preferredColorScheme(theme.colorScheme)
                // .onAppear: ana ekran TAMAMEN açılınca → arkadaki giriş sahnesi kaldırılır (açılış kayması sırasında kaldırılsa arka plan bir an boş görünürdü)
                .onAppear { homeShown = true; PerfLog.mark("giriş sahnesi kaldırıldı") }
        }
    }
}

#Preview { // Xcode önizleme | #Preview [SWIFT]: Xcode'da canlı önizleme (uygulamayı etkilemez)
    LoginView()
}
