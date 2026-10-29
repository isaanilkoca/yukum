//
//  LoginView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// BU EKRAN: giriş ekranı (uygulamanın ilk ekranı). Akış: alanları doldur → kontrol et → pakete koy → AuthService.login → HomeView
// BAĞLANTI: ContentView.swift bu ekranı açar | "Kayıt ol" → RoleSelectionView.swift | giriş başarılı → HomeView.swift
//           Paket kalıbı: Network/LoginRequest.swift | gönderen: Network/AuthService.swift → login | jeton saklanır: Network/Session.swift
struct LoginView: View { // LoginView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // @State [SWIFT]: ekranın hafızası; değer değişince ekran kendini yeniler
    @State private var emailOrPhone = "" // kullanıcının yazdığı e-posta ya da telefon
    @State private var password = ""
    @State private var errorMessage: String? // String? = boş olabilir | nil: hata yok, dolu: kırmızı yazılır
    @State private var isLoading = false // istek sürerken true → düğme kilitlenir
    @State private var loggedInUser: LoginUser? // giriş başarılıysa dolar | nil: henüz girmedi | kalıbı: Network/LoginRequest.swift → LoginUser

    var body: some View { // ekranın içeriği

        NavigationStack { // NavigationStack [SWIFT]: ekranlar arası geçiş + geri oku yönetir | "Kayıt ol" NavigationLink'i bunun içinde çalışır
            VStack(spacing: 40) { // elemanları alt alta dizer

                Text("Yüküm").font(.largeTitle).bold() // başlık

                // $ = iki yönlü bağ: yazılan yazı doğrudan değişkene gider | .never: baş harf büyümesin | .emailAddress: @ kolay çıkan klavye
                TextField("Email veya Telefon", text: $emailOrPhone).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).keyboardType(.emailAddress)

                SecureField("Şifre", text: $password).textFieldStyle(.roundedBorder) // SecureField [SWIFT]: yazılan nokta nokta görünür

                if let errorMessage { Text(errorMessage).foregroundColor(.red) } // if let: doluysa kırmızı yaz, nil ise çizilmez

                HStack(spacing: 50) { // yan yana iki eleman

                    Button("Giriş yap") { // tıklanınca süslü parantezdeki kod çalışır

                        // 1) Kontrol: boşsa API'ye gitme
                        if emailOrPhone.isEmpty || password.isEmpty { // isEmpty: yazı boş mu | ||: veya
                            errorMessage = "E-posta/telefon ve şifre gerekli."
                            return // return: burada dur, aşağıdaki kodlar çalışmaz
                        }

                        // 2) Paketi hazırla | BAĞLANTI: LoginRequest, Network/LoginRequest.swift'te tanımlı (form kağıdı), sıra oradaki alan sırasıyla aynı
                        // trimmingCharacters: baş/son boşlukları siler | UUID().uuidString [SWIFT]: rastgele benzersiz kimlik (API cihaz kimliği ister)
                        let body = LoginRequest(emailOrPhone: emailOrPhone.trimmingCharacters(in: .whitespaces), password: password, deviceId: UUID().uuidString)

                        // 3) API'ye gönder
                        Task { // Task [SWIFT]: düğme içinde await (bekleme) kullanmamızı sağlar; ekran donmaz
                            isLoading = true // düğme kilitlenir
                            errorMessage = nil // eski hatayı temizle
                            do { // do: dene | hata çıkarsa catch'lerden biri çalışır
                                // BAĞLANTI: AuthService, Network/AuthService.swift'te tanımlı. .login(body) oradaki func login'i çağırır, body'yi ona VERİR.
                                // login → post("/api/v1/auth/login") → API'ye POST → cevap LoginResponse'a çevrilir (kalıbı: Network/LoginRequest.swift) → buraya döner.
                                // try await: try = hata çıkabilir, await = cevabı bekle | hata olursa AuthError fırlatılır → aşağıdaki catch yakalar
                                let response = try await AuthService().login(body)
                                Session.accessToken = response.accessToken // BAĞLANTI: Network/Session.swift'e yazar; ListingService gibi servisler buradan okuyup "Authorization: Bearer" başlığına koyar
                                loggedInUser = response.user // dolunca aşağıdaki fullScreenCover HomeView'ı açar
                                print("GİRİŞ BAŞARILI: \(response.user.displayName) (\(response.user.role)) jeton uzunluğu: \(response.accessToken.count)") // geçici test çıktısı (Xcode konsolu) | jetonun kendisi yazılmaz
                            } catch let error as AuthError { // API "hayır" dedi (401, 423...) | AuthError: Network/AuthService.swift'te tanımlı
                                errorMessage = error.message // "E-posta veya şifre hatalı." gibi, kırmızı yazılır
                                print("GİRİŞ HATASI (API): \(error.message)") // geçici
                            } catch { // başka her hata: API kapalı, internet yok
                                errorMessage = "Sunucuya ulaşılamadı."
                                print("GİRİŞ HATASI (bağlantı/okuma): \(error)") // geçici: asıl hata nedeni konsolda
                            }
                            isLoading = false // düğme tekrar açılır
                        }

                    }.disabled(isLoading) // isLoading true iken basılamaz (çift tıklama olmasın)

                    NavigationLink("Kayıt ol") { // NavigationLink [SWIFT]: kendisi düğme, basınca süslü parantezdeki ekrana geçer (Button içine konmaz)
                        RoleSelectionView() // View/RoleSelectionView.swift → Yük Veren / Taşımacı seçimi
                    }

                }.padding()

            }.padding()
        }

        // BAĞLANTI: loggedInUser giriş başarılı olunca (response.user) dolar → dolunca HomeView tam ekran açılır.
        // HomeView'daki "Çıkış Yap" dismiss() ile bu ekranı kapatır → loggedInUser tekrar nil olur → giriş ekranına dönülür.
        // item: Identifiable ister, LoginUser'a bu yüzden Identifiable eklendi (Network/LoginRequest.swift).
        .fullScreenCover(item: $loggedInUser) { user in // [SWIFT]: loggedInUser dolunca tam ekran açar, nil olunca kapatır | $ = bağ | user: dolan kullanıcı (adı bizim)
            HomeView(user: user) // View/HomeView.swift'e kullanıcıyı veriyoruz
        }
    }
}

#Preview { // Xcode önizleme
    LoginView()
}
