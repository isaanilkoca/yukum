//
//  RoleSelectionView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 28.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// BU EKRAN: "Nasıl kayıt olmak istersiniz?" Yük Veren mi, Taşımacı mı seçilir.
// BAĞLANTI: Views/LoginView.swift'teki "Kayıt ol" NavigationLink'i bu ekranı açar.
//           Buradan: "Yük Veren" → Views/RegisterView.swift | "Taşımacı" → Views/CarrierRegisterView.swift
// NOT: Bu ekranda kendi NavigationStack'i yok; LoginView'daki NavigationStack'i kullanır (geri oku oradan gelir).
struct RoleSelectionView: View { // RoleSelectionView [BİZİM] ad | View [SWIFT]: bu bir ekran

    var body: some View { // ekranın içeriği

        VStack(spacing: 24) { // VStack [SWIFT]: elemanları alt alta dizer | spacing: elemanlar arası 24 nokta boşluk
            Text("Nasıl Kayıt Olmak İstersiniz ?").font(.title2).bold() // Text [SWIFT]: yazı | .font: boyut | .bold(): kalın

            HStack(spacing: 50) { // HStack [SWIFT]: elemanları yan yana dizer

                NavigationLink("Yük Veren") { // NavigationLink [SWIFT]: düğme gibi, basınca süslü parantezdeki ekrana geçer
                    RegisterView() // Views/RegisterView.swift → Yük Veren kayıt formu
                }.buttonStyle(.borderedProminent) // dolgulu (mavi) düğme görünümü

                NavigationLink("Taşımacı") {
                    CarrierRegisterView() // Views/CarrierRegisterView.swift → Taşımacı kayıt formu
                }.buttonStyle(.borderedProminent)
            }

        }.padding() // padding [SWIFT]: kenarlardan iç boşluk
    }
}

#Preview { // Xcode önizleme
    RoleSelectionView()
}
