//
//  RegisterView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import SwiftUI

struct RegisterView: View {
    
    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var companyName = ""
    @State private var kvkAccepted = false
    @State private var errorMessage : String?
    @State private var isLoading = false   // istek sürerken true; düğmeyi kilitlemek için
    @State private var isSuccess = false   // kayıt olunca true; başarı mesajını göstermek için


    var body: some View {
        
        GeometryReader { geo in
            
            ScrollView{
                
                VStack(spacing: 24){
                    
                    Text("Kayıt Ol ").font(.largeTitle).bold()
                    
                    TextField("Ad - Soyad ", text: $fullName).textFieldStyle(.roundedBorder)
                    
                    TextField("E-posta ", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress).textFieldStyle(.roundedBorder)
                    
                    TextField("Telefon ", text: $phone).textInputAutocapitalization(.never).keyboardType(.phonePad).textFieldStyle(.roundedBorder)
                    
                    SecureField("Şifre", text: $password ).textFieldStyle(.roundedBorder)
                    
                    TextField("Firma Adı (isteğe bağlı)", text: $companyName).textFieldStyle(.roundedBorder)
                    
                    Toggle("KVKK metnini onaylıyorum", isOn: $kvkAccepted)
                    
                    if let errorMessage { Text(errorMessage).foregroundColor(.red)}
                    
                    // Başarı mesajı: isSuccess true olunca görünür
                    if isSuccess { Text("Kayıt başarılı! Giriş yapabilirsiniz.").foregroundColor(.green) }

                    Button("Kayıt Ol") {
                        // 1) Boş alan kontrolü (isEmpty: yazı boş mu)
                        if fullName.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty {
                            errorMessage = "Lütfen zorunlu alanları doldurun."
                            return   // return: burada durur, API'ye gitmez
                        }
                        // 2) KVKK onayı (! = değil)
                        if !kvkAccepted {
                            errorMessage = "KVKK metnini onaylamanız gerekir."
                            return
                        }
                        // 3) İstek paketini hazırla
                        let body = RegisterRequest(
                            fullName: fullName.trimmingCharacters(in: .whitespaces),   // trimming: baş/son boşlukları siler
                            email: email.trimmingCharacters(in: .whitespaces),
                            password: password,   // sıra RegisterRequest'teki alan sırasıyla aynı olmalı
                            phone: phone.trimmingCharacters(in: .whitespaces),
                            cityId: 34,   // geçici sabit il (İstanbul)
                            companyName: companyName.isEmpty ? nil : companyName,   // boşsa nil: JSON'a hiç yazılmaz
                            kvkkAccepted: kvkAccepted
                        )
                        // 4) API'yi çağır
                        Task {   // Task: düğme içinde await kullanmamızı sağlar
                            isLoading = true
                            errorMessage = nil
                            do {   // do/catch: hata olursa catch'e düşer
                                _ = try await AuthService().register(body)   // _ = cevabı şimdilik kullanmıyoruz
                                isSuccess = true
                            } catch let error as AuthError {
                                errorMessage = error.message   // API'nin Türkçe mesajı
                            } catch {
                                errorMessage = "Sunucuya ulaşılamadı."   // API kapalı / bağlantı yok
                            }
                            isLoading = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)   // istek sürerken basılamaz

                }.padding().frame(minHeight: geo.size.height)

                
            }
        }
       
        
      
    
        
    }
}

#Preview {
    
    RegisterView()
    
}
