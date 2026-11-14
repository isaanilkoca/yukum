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
    @State private var spot: CGFloat = 0 // sahne spotu: 0 = kapalı, 1 = tam açık (SpotBeam) | koliler tamamen durunca açılır
    @State private var swing: Double = 0 // lambanın sallanma açısı (radyan) | swingLamp her karede günceller

    // Bantların ekrandaki yeri (ekran ortasından dikey uzaklık, nokta) ve eğimi (derece). Sıra: alttan yukarı.
    // 14 Kasım (kullanıcı: "aralıkları geniş, duruşu düzenli olsun"): 7 → 4 bant, EŞİT aralık (230 nokta) ve EŞİT eğim (5°, sırayla bir sağa bir sola)
    //   ekranın ortasına göre simetrik: ±115 ve ±345 → üstte başlık, altta koliler, ortada form bantların arasında nefes alır
    static let tapes: [(offsetY: CGFloat, angle: Double)] = [
        (345, 5), (115, -5), (-115, 5), (-345, -5)
    ]

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)

        ZStack { // ZStack [SWIFT]: elemanları üst üste dizer (arkadan öne)
            // en arkada 3B sahne; koliler durunca bantlamayı başlatır | yığın tamamen durunca spotu açar
            // withAnimation [SWIFT]: içindeki değişiklik animasyonla olur → spot 2,2 sn'de yavaşlayarak açılır (3B spotla aynı anda: BoxSceneRig › revealSpotlight)
            // YALNIZ KOYU MOD (14 Kasım, kullanıcı kararı): gündüz modunda spot, karartma ve sallanma yok.
            SceneBackground(onSettled: wrapScreen, onSpot: {
                guard colorScheme == .dark else { return }
                withAnimation(.easeOut(duration: 2.2)) { spot = 1 }
                swingLamp()
            })

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

            // SAHNE SPOTU: bantların ÜSTÜNDE (ekranı kararttığında bantlar da kararsın, koninin içinde kalanlar aydınlansın),
            // formun ve başlığın ALTINDA (LoginView onları bu görünümün üstüne çizer → hep okunur) | ⮕ Design/SpotBeam.swift
            if palette.isDark { SpotBeam(progress: spot, swing: swing, color: palette.beam) }
        }
        .ignoresSafeArea() // çentik, alt çubuk ve KLAVYE alanını yok say: klavye açılınca arka plan yerinden oynamasın
    }

    // BU FONKSİYON: asılı lambayı rüzgârda sallanır gibi sallar, sonra durdurur (kullanıcı: "ilk açılışta sallansın, sonra dursun").
    // SÖNÜMLÜ SARKAÇ: açı = A · e^(−t/τ) · sin(2π t / T) → her salınım bir öncekinden küçük, ~7 sn'de durur.
    //   A = 0,25 rad (~14°) ilk savrulma: koninin ucu ekrandan hafifçe taşar (14 Kasım kullanıcı: "az sallanıyor, hafif ekrandan çıkacak kadar")
    //   T = 2,2 sn bir gidiş-dönüş (ağır lamba hissi) | τ = 1,9 sn sönme hızı
    // NEDEN Task + bekleme: 30 kare/sn yeterli, kısa süreli; bittiğinde hiçbir iş kalmaz (pil harcamaz).
    // UCUZ: her karede yalnız hazır ışık resmi döndürülür (Design/SpotBeam › PERFORMANS notu).
    // ⮕ KULLANIM [swingLamp]: kullanır: body › SceneBackground.onSpot (yalnız koyu mod)
    private func swingLamp() {
        Task {
            for frame in 0...210 { // 210 kare × 33 ms ≈ 7 sn
                let t = Double(frame) / 30
                swing = 0.25 * exp(-t / 1.9) * sin(2 * .pi * t / 2.2)
                try? await Task.sleep(for: .milliseconds(33))
            }
            swing = 0 // tam dik dursun
        }
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
