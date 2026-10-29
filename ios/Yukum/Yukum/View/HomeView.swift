//
//  HomeView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 29.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// BU EKRAN: giriş sonrası ana ekran. Rol "Shipper" ise Yük Veren, değilse Taşımacı anasayfası gösterir.
// BAĞLANTI: View/LoginView.swift giriş başarılı olunca .fullScreenCover ile bu ekranı açar ve giriş yapan kullanıcıyı verir.
struct HomeView: View { // HomeView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // user: giriş yapan kişi (ad, rol) | kalıbı: Network/LoginRequest.swift → struct LoginUser
    // let [SWIFT]: değişmeyen değer | dışarıdan verilir: LoginView'daki "loggedInUser" dolunca HomeView(user: user) ile buraya gelir
    let user: LoginUser

    @Environment(\.dismiss) private var dismiss // @Environment [SWIFT]: sistemden hazır değer al | dismiss: "bu ekranı kapat" komutu | çıkışta kullanılır

    var body: some View { // ekranın içeriği

        NavigationStack { // NavigationStack [SWIFT]: ekranlar arası geçiş + geri oku yönetir | NavigationLink'ler bunun içinde çalışır

            VStack(spacing: 24) { // elemanları alt alta dizer

                Text("Hoş Geldin \(user.displayName)").font(.title2).bold() // \( ) = yazının içine değişken koyar | user.displayName: LoginUser'daki ad alanı

                // user.role API'den "Shipper" ya da "Carrier" gelir | yazımı API ile birebir aynı olmalı
                if user.role == "Shipper" { // == karşılaştırır | doğruysa Yük Veren görünümü

                    Text("Yük Veren Anasayfası")
                    NavigationLink("İlan Ver") { // basınca süslü parantezdeki ekrana geçer (NavigationStack içinde olduğu için geri oku otomatik)
                        CreateListingView() // View/CreateListingView.swift → yeni ilan formu
                    }.buttonStyle(.borderedProminent)

                } else { // Shipper değilse (Carrier)
                    Text("Taşımacı AnaSayfası") // sonra açık ilanlar listesi gelecek
                }

                Button("Çıkış Yap") { // Button [SWIFT]: tıklanınca süslü parantezdeki kod çalışır
                    dismiss() // bu ekranı kapatır → LoginView'daki loggedInUser nil olur → giriş ekranına dönülür
                }.buttonStyle(.borderedProminent)

            }.padding()
            .navigationTitle("Yüküm") // [SWIFT] üst çubuktaki başlık
        }
    }
}
