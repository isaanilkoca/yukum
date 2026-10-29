//
//  LoginView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import SwiftUI

struct LoginView: View {
    
    // state ekranın hatırlaması gereken değer  kllanıcı yazdıkca değişir ve ekran kendini yeniler
    @State private var emailOrPhone = ""
    @State private var password = ""
    @State private var errorMessage : String?
    @State private var isLoading = false // istek sürerken true → düğme kilitlenir
    @State private var loggedInUser: LoginUser? // giriş başarılıysa dolar | ? = boş olabilir (nil: henüz girmedi)

    
    var body: some View {
        
        NavigationStack{
            VStack(spacing: 40){
                
                //Baslık
                Text("Yüküm").font(.largeTitle).bold()
                
                //Email ya da telefon
                TextField("Email veya Telefon", text: $emailOrPhone).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).keyboardType(.emailAddress)
                
                //Şifre için
                SecureField("Şifre", text: $password).textFieldStyle(.roundedBorder)
                
                if let errorMessage { Text(errorMessage).foregroundColor(.red) } // doluysa kırmızı yaz, nil ise çizilmez

            
                
                HStack(spacing: 50){
               
                    Button("Giriş yap"){
                        
                        // 1) Kontrol: boşsa API'ye gitme
                        if emailOrPhone.isEmpty || password.isEmpty {
                            errorMessage = "E-posta/telefon ve şifre gerekli."
                            return
                        }
                        // 2) Paketi hazırla (sıra LoginRequest'teki alan sırasıyla aynı)
                        let body = LoginRequest(emailOrPhone: emailOrPhone.trimmingCharacters(in: .whitespaces), password: password, deviceId: UUID().uuidString)
                        // 3) API'ye gönder
                        Task {
                            isLoading = true
                            errorMessage = nil
                            do {
                                let response = try await AuthService().login(body) // bu sefer cevabı kullanıyoruz (kayıtta _ = idi)
                                loggedInUser = response.user // dolunca "Hoş geldin" görünecek
                                print("GİRİŞ BAŞARILI: \(response.user.displayName) (\(response.user.role)) jeton uzunluğu: \(response.accessToken.count)") // geçici: Xcode alt konsoluna yazar (jetonun kendisini yazmıyoruz)
                            } catch let error as AuthError {
                                errorMessage = error.message // "E-posta veya şifre hatalı." gibi
                                print("GİRİŞ HATASI (API): \(error.message)") // geçici konsol çıktısı
                            } catch {
                                errorMessage = "Sunucuya ulaşılamadı."
                                print("GİRİŞ HATASI (bağlantı/okuma): \(error)") // geçici: asıl hata nedeni konsolda
                            }
                            isLoading = false
                        }
                        
                    }.disabled(isLoading)// isLoading true iken basılamaz (çift tıklama olmasın)

                    NavigationLink("Kayıt ol"){ // NavigationLink [SWIFT]: kendisi düğme, basınca süslü parantez içindeki ekrana geçer (Button içine konmaz)
                        RoleSelectionView() // rol seçimi ekranı: Yük Veren / Taşımacı
                    }

                }.padding()
               
                
            }.padding()
            
        }
        
        .fullScreenCover(item: $loggedInUser) { user in  // [SWIFT]: loggedInUser dolunca tam ekran açar, nil olunca kapatır | $ = bağ
            
            HomeView(user: user) // dolan kullanıcıyı HomeViewa veriyoruz
        }
          
        }
      
    
}

#Preview {
    LoginView()
}
