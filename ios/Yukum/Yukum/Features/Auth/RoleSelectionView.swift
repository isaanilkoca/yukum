//
//  RoleSelectionView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 28.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: RoleSelectionView (rol seçimi) ────────────────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ İki düğme                →  NavigationLink → RegisterView (Yük Veren) | CarrierRegisterView (Taşımacı)   (ViewModel yok: yalnız yönlendirme)
// │ Gelen yer                →  Features/Auth/LoginView "Kayıt ol"
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: "Nasıl kayıt olmak istersiniz?" Yük Veren mi, Taşımacı mı seçilir.
// BAĞLANTI: Features/Auth/LoginView.swift'teki "Kayıt ol" NavigationLink'i bu ekranı açar.
//           Buradan: "Yük Veren" → Features/Auth/RegisterView.swift | "Taşımacı" → Features/Auth/CarrierRegisterView.swift
// NOT: Bu ekranda kendi NavigationStack'i yok; LoginView'daki NavigationStack'i kullanır (geri oku oradan gelir).
// ⮕ KULLANIM [RoleSelectionView]: kullanır: LoginView › body
struct RoleSelectionView: View { // RoleSelectionView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View { // ekranın içeriği

        VStack(spacing: 24) { // VStack [SWIFT]: elemanları alt alta dizer | spacing: elemanlar arası 24 nokta boşluk
            Text("Nasıl Kayıt Olmak İstersiniz ?").font(.title2).bold() // Text [SWIFT]: yazı | .font: boyut | .bold(): kalın

            HStack(spacing: 50) { // HStack [SWIFT]: elemanları yan yana dizer

                NavigationLink("Yük Veren") { // NavigationLink [SWIFT]: düğme gibi, basınca süslü parantezdeki ekrana geçer
                    RegisterView() // Features/Auth/RegisterView.swift → Yük Veren kayıt formu
                }.buttonStyle(.borderedProminent) // dolgulu (mavi) düğme görünümü | .buttonStyle [SWIFT]: düğme görünüm stili

                NavigationLink("Taşımacı") {
                    CarrierRegisterView() // Features/Auth/CarrierRegisterView.swift → Taşımacı kayıt formu
                }.buttonStyle(.borderedProminent)
            }

        }.padding() // padding [SWIFT]: kenarlardan iç boşluk | .padding [SWIFT]: etrafında boşluk bırakır
    }
}

#Preview { // Xcode önizleme | #Preview [SWIFT]: Xcode'da canlı önizleme (uygulamayı etkilemez)
    RoleSelectionView()
}
