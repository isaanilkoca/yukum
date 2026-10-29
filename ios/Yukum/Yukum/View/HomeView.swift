//
//  HomeView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 29.10.2026.
//

import SwiftUI

// BU EKRAN: giriş sonrası ana ekran. Rol "Shipper" ise Yük Veren, değilse Taşımacı anasayfası gösterir.
// BAĞLANTI: View/LoginView.swift giriş başarılı olunca .fullScreenCover ile bu ekranı açar ve giriş yapan kullanıcıyı verir.
struct HomeView: View { // giriş sonrası ana ekran

    // user: giriş yapan kişi (ad, rol) | kalıbı: Network/LoginRequest.swift → struct LoginUser
    // Nereden geliyor: LoginView'daki "loggedInUser" dolunca HomeView(user: user) ile buraya verilir
    let user : LoginUser
    
    @Environment(\.dismiss) private var dismiss // [SWIFT]: "bu ekranı kapat" komutu | çıkışta kullanacağız
    
    var body: some View {
        
        NavigationStack{
            
            
            VStack(spacing: 24){
                
                Text("Hoş Geldin \(user.displayName)").font(.title2).bold()  // \( ) = yazının içine değişken koyar
                
                // role API'den "Shipper" ya da "Carrier" gelir | yazımı API ile aynı olmalı
                if user.role == "Shipper"{

                    Text("Yük Veren Anasayfası")
                    NavigationLink("İlan Ver") { // basınca süslü parantez içindeki ekrana geçer (NavigationStack içinde olduğu için geri oku otomatik gelir)
                        CreateListingView() // View/CreateListingView.swift → yeni ilan formu
                    }.buttonStyle(.borderedProminent)
                    
                }else {
                    Text("Taşımacı AnaSayfası") // sonra açık ilanlar listesi
                }
                
                Button("Çıkış Yap"){
                    dismiss() // ekranı kapatır , giriş ekranına döner
                }.buttonStyle(.borderedProminent)
                
                
            }.padding()
            .navigationTitle("Yüküm")
        }
       
        
    }
    
}




