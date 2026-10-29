//
//  RegisterView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// BU EKRAN: Yük Veren kayıt formu. Akış: alanları doldur → kontrol et → pakete koy → AuthService ile API'ye gönder → sonucu göster
// BAĞLANTI: View/RoleSelectionView.swift'teki "Yük Veren" NavigationLink'i bu ekranı açar.
//           Paket kalıbı: Network/RegisterRequest.swift → RegisterRequest | gönderen: Network/AuthService.swift → register
struct RegisterView: View { // RegisterView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // @State [SWIFT]: ekranın hafızası; değer değişince ekran kendini yeniler | private: yalnız bu ekran kullanır
    @State private var fullName = "" // ad soyad | "" = başta boş yazı
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var companyName = "" // firma adı, isteğe bağlı
    @State private var kvkAccepted = false // KVKK Toggle'ı: açık = true, kapalı = false
    @State private var errorMessage: String? // String? = boş olabilir | nil: hata yok, dolu: ekranda kırmızı yazılır
    @State private var isLoading = false // istek sürerken true → düğme kilitlenir
    @State private var isSuccess = false // kayıt olunca true → yeşil mesaj çıkar

    var body: some View { // ekranın içeriği

        GeometryReader { geo in // GeometryReader [SWIFT]: ekranın ölçüsünü verir | geo: bu ölçü (adı bizim)

            ScrollView { // ScrollView [SWIFT]: uzun formda kaydırma sağlar

                VStack(spacing: 24) { // elemanları alt alta dizer

                    Text("Kayıt Ol ").font(.largeTitle).bold()

                    // TextField(ipucu, text: $değişken) | $ = iki yönlü bağ: yazılan yazı doğrudan değişkene gider, değişken değişirse kutu da değişir
                    TextField("Ad - Soyad ", text: $fullName).textFieldStyle(.roundedBorder) // .roundedBorder: yuvarlak çerçeveli kutu

                    TextField("E-posta ", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress).textFieldStyle(.roundedBorder) // .never: baş harf büyümesin | .emailAddress: @ kolay çıkan klavye

                    TextField("Telefon ", text: $phone).textInputAutocapitalization(.never).keyboardType(.phonePad).textFieldStyle(.roundedBorder) // .phonePad: telefon klavyesi

                    SecureField("Şifre", text: $password).textFieldStyle(.roundedBorder) // SecureField [SWIFT]: yazılan nokta nokta görünür

                    TextField("Firma Adı (isteğe bağlı)", text: $companyName).textFieldStyle(.roundedBorder)

                    Toggle("KVKK metnini onaylıyorum", isOn: $kvkAccepted) // Toggle [SWIFT]: aç/kapa anahtarı | isOn: durum $kvkAccepted'a true/false yazılır

                    if let errorMessage { Text(errorMessage).foregroundColor(.red) } // if let: errorMessage doluysa içini çıkarıp göster, nil ise satır çizilmez

                    if isSuccess { Text("Kayıt başarılı! Giriş yapabilirsiniz.").foregroundColor(.green) } // isSuccess true olunca görünür

                    Button("Kayıt Ol") { // tıklanınca süslü parantezdeki kod çalışır

                        // ---- 1) KONTROLLER: API'ye gitmeden ekranda yakalıyoruz ----
                        if fullName.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty { // isEmpty: yazı boş mu | ||: veya
                            errorMessage = "Lütfen zorunlu alanları doldurun."
                            return // return: burada dur, aşağıdaki kodlar çalışmaz, API'ye gidilmez
                        }
                        if !kvkAccepted { // !: değil → onay verilmemişse
                            errorMessage = "KVKK metnini onaylamanız gerekir."
                            return
                        }

                        // ---- 2) PAKETİ HAZIRLA ----
                        // BAĞLANTI: RegisterRequest, Network/RegisterRequest.swift'te tanımlı (form kağıdı). Burada dolu bir örneğini üretip "body"ye atıyoruz.
                        // DİKKAT: parametre sırası RegisterRequest'teki alan sırasıyla aynı olmalı.
                        let body = RegisterRequest( // let [SWIFT]: bir kez atanan, değişmeyen değişken | body [BİZİM] ad: gönderilecek dolu paket
                            fullName: fullName.trimmingCharacters(in: .whitespaces), // trimmingCharacters [SWIFT]: baş/son boşlukları siler (API reddetmesin)
                            email: email.trimmingCharacters(in: .whitespaces),
                            password: password,
                            phone: phone.trimmingCharacters(in: .whitespaces),
                            cityId: 34, // geçici sabit il (İstanbul); API il numarası ister
                            companyName: companyName.isEmpty ? nil : companyName, // a ? b : c = a doğruysa b, değilse c | boşsa nil: JSON'a hiç yazılmaz
                            kvkkAccepted: kvkAccepted
                        )

                        // ---- 3) API'YE GÖNDER ----
                        Task { // Task [SWIFT]: düğme içinde await (bekleme) kullanabilmemizi sağlar; ekran donmaz
                            isLoading = true // düğme kilitlenir
                            errorMessage = nil // eski hatayı temizle
                            do { // do: dene | hata çıkarsa aşağıdaki catch'lerden biri çalışır
                                // BAĞLANTI: AuthService, Network/AuthService.swift'te tanımlı. .register(body) oradaki func register'ı çağırır, body'yi ona VERİR.
                                // Cevap RegisterResponse olarak döner (kullanmıyoruz: _ =). Hata olursa AuthError fırlatılır.
                                // try await: try = hata çıkabilir, await = cevabı bekle
                                _ = try await AuthService().register(body)
                                isSuccess = true // başarılı → yeşil mesaj çıkar
                            } catch let error as AuthError { // API "hayır" dedi (400, 409...) | AuthError: Network/AuthService.swift'te tanımlı
                                errorMessage = error.message // API'nin Türkçe mesajı kırmızı yazılır
                            } catch { // başka her hata: API kapalı, internet yok
                                errorMessage = "Sunucuya ulaşılamadı."
                            }
                            isLoading = false // düğme tekrar açılır
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading) // .disabled: isLoading true iken basılamaz (çift tıklama olmasın)

                }.padding().frame(minHeight: geo.size.height) // frame(minHeight:): en az ekran boyu → içerik ortada durur, uzunsa kaydırılır
            }
        }
    }
}

#Preview { // Xcode önizleme
    RegisterView()
}
