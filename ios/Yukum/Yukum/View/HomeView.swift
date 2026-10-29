//
//  HomeView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 29.10.2026.
//

import SwiftUI

struct HomeView: View { // giriş sonrası ana ekran
    
    let user : LoginUser // giriş yapan kişi | LoginView ekranı açarken verir (tanımı: Network/LoginRequest.swift)
    
    @Environment(\.dismiss) private var dismiss // [SWIFT]: "bu ekranı kapat" komutu | çıkışta kullanacağız
    
    var body: some View {
        
        VStack(spacing: 24){
            
            Text("Hoş Geldin \(user.displayName)").font(.title2).bold()  // \( ) = yazının içine değişken koyar
            
            // role API'den "Shipper" ya da "Carrier" gelir | yazımı API ile aynı olmalı
            if user.role == "Shipper"{
                
                Text("Yük Veren AnaSayfası") // sonra: ilan ver + ilanlarım
                
            }else {
                Text("Taşımacı AnaSayfası") // sonra açık ilanlar listesi
            }
            
            Button("Çıkış Yap"){
                dismiss() // ekranı kapatır , giriş ekranına döner
            }.buttonStyle(.borderedProminent)
            
            
        }.padding()
        
    }
    
}


