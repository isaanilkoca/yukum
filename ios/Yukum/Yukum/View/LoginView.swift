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

    
    var body: some View {
        
            
            VStack(spacing: 40){
                
                //Baslık
                Text("Yüküm").font(.largeTitle).bold()
                
                //Email ya da telefon
                TextField("Email veya Telefon", text: $emailOrPhone).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).keyboardType(.emailAddress)
                
                //Şifre için
                SecureField("Şifre", text: $password).textFieldStyle(.roundedBorder)
                
                HStack(spacing: 50){
               
                    Button("Giriş yap"){
                        
                    }
                    Button("Kayıt ol"){
                        
                    
                    }
                }.padding()
               
                
            }.padding()
        }
      
    
}

#Preview {
    LoginView()
}
