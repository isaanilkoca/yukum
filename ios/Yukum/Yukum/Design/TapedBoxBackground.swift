//
//  TapedBoxBackground.swift
//  Yukum
//
//  Hazır arka plan: düşen koliler (3B) + koliler durunca ekranı saran bantlar (2B). Bir ekranın arkasına TEK SATIRLA konur.
//

import SwiftUI    // [SWIFT] ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: TapedBoxBackground.swift ─────────────────────────────────────────
// │ GELEN     : Views/LoginView.swift → ZStack'in en arkasında TapedBoxBackground()
// │ GİDEN     : Design/BoxSceneBackground.swift (3B koli sahnesi) | Design/ScreenTape.swift (bantlar) | Design/DesignPalette.swift (renkler)
// │ TEKNİK    : SwiftUI ZStack: arkada 3B sahne, önünde bantlar. Ekranın yazıları/alanları bunun ÜSTÜNE gelir.
// │ REHBER    : Design/00_Rehber_Design.swift (hangi teknik nerede, okuma sırası)
// └──────────────────────────────────────────────────────────────────────

// ZİNCİR: ekran açılır → SceneBackground kolileri düşürür → yığın yerleşince SceneRig "durdu" der (onSettled)
//         → wrapScreen() → tapesPulled 0'dan 7'ye birer birer artar → her artışta bir şerit uzar + telefon hafifçe titrer → sahne durur.
// NEDEN ayrı görünüm: koli + bant birlikteliği birden çok ekranda (giriş, kayıt) kullanılacak; her ekrana aynı kodu kopyalamamak için.
// NEDEN bantlar arayüzün ARKASINDA: tüm ekranı geçebilsinler ama yazıları ve alanları kapatmasınlar.
// ⮕ KULLANIM [TapedBoxBackground]: kullanır: LoginView › body
struct TapedBoxBackground: View { // TapedBoxBackground [BİZİM] ad | View [SWIFT]: bu bir ekran parçası

    @Environment(\.colorScheme) private var colorScheme // [SWIFT] telefon açık modda mı koyu modda mı
    @State private var tapesPulled = 0 // şu ana kadar çekilen bant sayısı (0 → tapes.count)

    // Bantların ekrandaki yeri (ekran ortasından dikey uzaklık, nokta) ve eğimi (derece). Sıra: alttan yukarı.
    static let tapes: [(offsetY: CGFloat, angle: Double)] = [
        (345, -5), (232, 6), (118, -8), (8, 4), (-88, -6), (-172, 5), (-392, -4)
    ]

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)

        ZStack { // ZStack [SWIFT]: elemanları üst üste dizer (arkadan öne)
            SceneBackground(onSettled: wrapScreen) // en arkada 3B sahne; koliler durunca bantlamayı başlatır

            // Bantlar: bir soldan bir sağdan (index çift/tek), her biri kendi açısında.
            ForEach(Self.tapes.indices, id: \.self) { index in
                let tape = Self.tapes[index]
                ScreenTape(text: "YÜKÜM", color: palette.screenTape, fromLeading: index.isMultiple(of: 2),
                           progress: index < tapesPulled ? 1 : 0) // sırası gelen şerit 0 → 1 olur
                    .rotationEffect(.degrees(tape.angle)) // [SWIFT] döndür
                    .offset(y: tape.offsetY)
                    .animation(.easeOut(duration: 0.5), value: tapesPulled) // [SWIFT] tapesPulled değişince bu şerit animasyonla uzar
            }
            .sensoryFeedback(.impact(weight: .light), trigger: tapesPulled) // [SWIFT] her bantta telefonda hafif titreşim (yalnız gerçek cihaz)
        }
        .ignoresSafeArea() // çentik, alt çubuk ve KLAVYE alanını yok say: klavye açılınca arka plan yerinden oynamasın
    }

    // ⮕ KULLANIM [wrapScreen]: kullanır: SceneBackground › onSettled (koliler durunca 1 kez)
    private func wrapScreen() {
        Task {
            for count in 1...Self.tapes.count {
                tapesPulled = count
                try? await Task.sleep(for: .seconds(0.22)) // bantlar arası kısa bekleme → "cırt, cırt, cırt"
            }
        }
    }
}

#Preview { // [SWIFT] Xcode'da sağda canlı önizleme; uygulamayı etkilemez
    TapedBoxBackground()
}
