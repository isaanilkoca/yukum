//
//  RoleSelectionView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 28.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: RoleSelectionView (TEK KAYIT EKRANI) ───────────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ Hesap türü seçici        →  role (@State, bu ekranın)            →  (ViewModel yok: yalnız hangi formun çizileceği)
// │ Yük Veren alanları       →  Views/RegisterView (kendi RegisterViewModel'i)        →  POST /api/v1/auth/register/shipper
// │ Taşımacı alanları        →  Views/CarrierRegisterView (kendi CarrierRegisterViewModel'i) →  POST /api/v1/auth/register/carrier
// │ Gelen yer                →  Views/LoginView "Kayıt ol" (girişte seçili hesap türünü verir)
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN (14 Kasım tasarımı): "Kayıt ol" tek ekran. Önceden iki adımdı (önce rol seçme ekranı, sonra form); şimdi rol formun tepesinde seçilir.
// TASARIM: giriş ekranıyla aynı dil — renk geçişi + ışık haleleri, yarı saydam kart (FormCard), etiketli kutular (LabeledInput), turuncu düğme.
//   Arka plan SAKİN: düşen koli ve spot YOK (uzun form doldurulurken dikkat dağılmasın, telefon yorulmasın).
// NEDEN iki ayrı form görünümü korunuyor: iki rolün alanları, doğrulaması ve API adresi farklı; ViewModel'ler zaten ayrı (RegisterViewModel, CarrierRegisterViewModel).
//   Bu ekran yalnız hangisinin çizileceğini seçer. Rol değiştirilince diğer formun alanları boş başlar (her formun kendi hafızası var).
// NOT: kendi NavigationStack'i yok; LoginView'daki NavigationStack'i kullanır (geri oku oradan gelir).
// ⮕ KULLANIM [RoleSelectionView]: kullanır: LoginView › body
struct RoleSelectionView: View { // RoleSelectionView [BİZİM] ad (dosya adı korunuyor; artık tek kayıt ekranı) | View [SWIFT]: bu bir ekran

    @Environment(\.colorScheme) private var colorScheme // [SWIFT] açık/koyu mod → Palette
    @State private var role: LoginRole // seçili hesap türü | başlangıç değeri girişten gelir

    // init: girişte hangi hesap türü seçiliyse kayıt da o türle açılır | State(initialValue:) [SWIFT]: @State'i elle başlatma yolu
    init(initialRole: LoginRole = .shipper) {
        _role = State(initialValue: initialRole)
    }

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark) // ⮕ Design/DesignPalette.swift

        ZStack {
            // SAKİN ARKA PLAN: giriş ekranının renk geçişi + iki bulanık ışık halesi (3B sahne yok)
            LinearGradient(colors: [palette.skyTop, palette.skyBottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            Ellipse().fill(palette.glowA).frame(width: 380, height: 320).blur(radius: 95).offset(x: -120, y: -220)
            Ellipse().fill(palette.glowB).frame(width: 360, height: 300).blur(radius: 95).offset(x: 130, y: 200)

            ScrollView { // ScrollView [SWIFT]: uzun formda kaydırma (Taşımacı formu ekrandan uzun)
                VStack(spacing: 18) {
                    // BAŞLIK
                    VStack(spacing: 6) {
                        Text("Hesap oluştur")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(palette.title)
                        Text("Birkaç bilgiyle hemen başla.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(palette.title.opacity(0.7))
                    }
                    .padding(.top, 8)

                    FormCard { // ⮕ Design/FormStyle.swift
                        // Hesap türü: girişteki seçiciyle aynı görünüm | .segmented [SWIFT]: yan yana parçalı anahtar
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Hesap türü").font(.footnote.weight(.semibold)).foregroundStyle(palette.label)
                            Picker("Hesap türü", selection: $role) {
                                ForEach(LoginRole.allCases) { option in Text(option.title).tag(option) } // ⮕ Models/Auth/LoginRole.swift
                            }
                            .pickerStyle(.segmented)
                        }

                        // Seçili role göre form alanları | .transition: değişince yumuşak geçiş
                        if role == .shipper {
                            RegisterView()        // ⮕ Views/RegisterView.swift (Yük Veren alanları + Kayıt ol)
                        } else {
                            CarrierRegisterView() // ⮕ Views/CarrierRegisterView.swift (Taşımacı alanları + araç + Kayıt ol)
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: role) // [SWIFT] rol değişince kart boyu yumuşakça uzar/kısalır
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively) // [SWIFT] kaydırınca klavye kapanır
        }
        .navigationBarTitleDisplayMode(.inline) // geri oku kalır, büyük başlık çubuğu yer kaplamaz
    }
}

#Preview { // Xcode önizleme | #Preview [SWIFT]: Xcode'da canlı önizleme (uygulamayı etkilemez)
    NavigationStack { RoleSelectionView() }
}
