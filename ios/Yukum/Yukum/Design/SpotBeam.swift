//
//  SpotBeam.swift
//  Yukum
//
//  Sahne spotu (limelight): ekran kararır, tepede asılı lambadan inen loş beyaz ışık konisi giriş alanlarını aydınlatır.
//  Açılışta lamba rüzgârda sallanır gibi sallanır, sonra durur. YALNIZ KOYU MODDA (TapedBoxBackground karar verir).
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: SpotBeam.swift ─────────────────────────────────────────
// │ GELEN     : Design/TapedBoxBackground.swift → progress 0 → 1 (açılış), swing (sallanma açısı, her karede)
// │ GİDEN     : Design/DesignPalette.swift (beam: ışık rengi)
// │ EŞİ       : Design/BoxSceneRig.swift › revealSpotlight → kolilere düşen 3B ışık (aynı anda açılır, yalnız koyu mod)
// │ TEKNİK    : yalnız SwiftUI (Path, gradient, mask, blendMode, drawingGroup). 3B değil.
// │ REHBER    : Design/00_Rehber_Design.swift
// └──────────────────────────────────────────────────────────────────────
//
// TASARIM KARARLARI (14 Kasım, kullanıcıyla adım adım):
//   • Parlaklık ışığı güçlendirerek değil ÇEVREYİ KARARTARAK verilir (zıtlık). Işığın kendisi loş, kenarları keskin.
//   • Koni FORMA (e-posta + şifre alanları) iner; altta yuvarlak ışık havuzu YOK → koni aşağı doğru yumuşakça söner.
//   • Lamba asılıdır: açılışta sönümlü sarkaç gibi sallanır (TapedBoxBackground › swingLamp); koninin ucu ekrandan hafifçe taşar.
//
// PERFORMANS (14 Kasım, kullanıcı: "çok kasıyor"):
//   ÖNCE: sallanma açısı her karede değişince koni YENİDEN hesaplanıyor, ekran boyu bulanıklıklar (blur) her karede yeniden çiziliyordu.
//   ŞİMDİ: ışık bir katmanda (SpotLayer) çizilir ve .drawingGroup() [SWIFT] ile TEK RESME dönüştürülür; sallanma yalnız bu resmi
//          döndürür (.rotationEffect). Döndürme ekran kartı için neredeyse bedava; resim yalnız açılış animasyonunda yeniden çizilir.
//   NEDEN katman ekrandan BÜYÜK (margin): resim döndürülünce köşeler içeri girer; karartma ekranın kenarlarını açıkta bırakmasın diye
//          katman her yönde ekranın yarısı kadar taşar.
// ⮕ KULLANIM [SpotBeam]: kullanır: TapedBoxBackground › body
struct SpotBeam: View, Animatable {
    var progress: CGFloat  // 0 = kapalı, 1 = tam açık
    var swing: Double = 0  // sallanma açısı (radyan): + sağa, - sola | asma noktası çevresinde döner
    let color: Color

    var animatableData: CGFloat { // [SWIFT] animasyonla değişecek değer (swing ayrıca her karede dışarıdan verilir)
        get { progress }
        set { progress = newValue }
    }

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View {
        GeometryReader { geo in // [SWIFT] ekranın ölçüsünü verir
            let w = geo.size.width, h = geo.size.height
            let margin = max(w, h) * 0.5 // katmanın ekrandan taşma payı (yukarıdaki not)
            let pivotY = h * SpotLayer.pivotRatio
            SpotLayer(screen: geo.size, margin: margin, progress: progress, color: color)
                .frame(width: w + margin * 2, height: h + margin * 2)
                .drawingGroup() // [SWIFT] içeriği tek resme çevirir → döndürme ucuz
                // asma noktası çevresinde döner | anchor: büyük katman içinde asma noktasının oranı
                .rotationEffect(.radians(swing), anchor: UnitPoint(x: 0.5, y: (margin + pivotY) / (h + margin * 2)))
                .position(x: w / 2, y: h / 2)
        }
        .allowsHitTesting(false) // [SWIFT] dokunuşları alttaki forma bırak
    }
}

// BU GÖRÜNÜM: spotun kendisi (karartma + koni + lamba), DÖNMEMİŞ hâliyle. Koordinatlar margin kadar kaydırılmış (katman ekrandan büyük).
// KATMANLAR (arkadan öne):
//   1. KARARTMA   : tüm katmanı %72 karartan perde; koni bu perdeden OYULUR (yumuşak kenarlı, aşağı doğru kapanan delik)
//   2. HAVA       : koninin etrafında çok hafif bulanık ışık (havadaki tozun ışığı saçması)
//   3. HUZME      : keskin kenarlı koni; tepede yoğun, aşağı doğru söner
//   4. ÇEKİRDEK   : ortada daha parlak dar şerit → derinlik
//   5. KENAR HATTI: koninin iki kenarında 1 noktalık ince çizgi
//   6. LAMBA      : asma çubuğu + koyu gövde + parlayan mercek + hafif parlama
// .plusLighter [SWIFT]: renkleri TOPLAYARAK karıştırır → ışık altındakini örtmez, aydınlatır.
// ⮕ KULLANIM [SpotLayer]: kullanır: SpotBeam › body
private struct SpotLayer: View {
    static let pivotRatio: CGFloat = 0.035 // asma noktası: ekran yüksekliğinin %3,5'i (SpotBeam döndürürken de kullanır)
    let screen: CGSize
    let margin: CGFloat
    let progress: CGFloat
    let color: Color

    var body: some View {
        let w = screen.width, h = screen.height, m = margin
        let total = h + 2 * m                                 // katmanın toplam yüksekliği (gradient oranları için)
        let cx = m + w / 2
        let pivotY = m + h * Self.pivotRatio                  // ASMA NOKTASI: lamba buradan sarkar
        let lampY = m + h * 0.075                             // lambanın merceği: üst bandın hemen altı
        let endY = m + h * 0.72                               // koninin söndüğü yer: formun altı (e-posta + şifre alanları içinde kalır)
        let topW: CGFloat = 40                                // koninin lambadan çıktığı genişlik
        let bottomW = topW + (w * 0.95 - topW) * progress     // ORTADAN YAYILMA: dipteki genişlik 40 → formu kaplayacak kadar
        let fade = min(1, progress * 2.5)                     // ilk ~0,9 sn'de tam görünür
        // Gradient başı/sonu: koninin tepesi ve dibi (katman ekrandan büyük olduğu için .top/.bottom değil, oran)
        let beamTop = UnitPoint(x: 0.5, y: lampY / total), beamEnd = UnitPoint(x: 0.5, y: endY / total)

        ZStack {
            // 1) KARARTMA: perde, koni oyulmuş | delik aşağı doğru kapanır (koni söndükçe karanlık geri gelir)
            Rectangle()
                .fill(Color.black.opacity(0.72 * fade)) // loştan biraz koyu, abartısız
                .mask { // [SWIFT] mask: perdenin yalnız maskenin dolu yerleri görünür
                    ZStack {
                        Rectangle() // her yer dolu…
                        // …koni SİLİNİR (destinationOut [SWIFT]: üstüne çizilen yeri alttakinden çıkarır) | blur: deliğin kenarı yumuşak
                        cone(cx, lampY, endY, topW * 1.3, bottomW * 1.05)
                            .fill(LinearGradient(colors: [.black, .black.opacity(0.85), .black.opacity(0)], startPoint: beamTop, endPoint: beamEnd))
                            .blur(radius: 12).blendMode(.destinationOut)
                    }
                    .compositingGroup() // [SWIFT] silme işlemi yalnız bu grubun içinde olsun
                }

            ZStack {
                // 2) HAVA: koninin etrafında hafif bulanık ışık
                cone(cx, lampY, endY, topW * 1.6, bottomW * 1.1)
                    .fill(LinearGradient(colors: [color.opacity(0.05), color.opacity(0.0)], startPoint: beamTop, endPoint: beamEnd))
                    .blur(radius: 10)
                // 3) HUZME: keskin kenar, tepede yoğun → aşağıda söner (dipte sert kenar yok)
                cone(cx, lampY, endY, topW, bottomW)
                    .fill(LinearGradient(stops: [.init(color: color.opacity(0.13), location: 0), .init(color: color.opacity(0.07), location: 0.35),
                                                 .init(color: color.opacity(0.035), location: 0.75), .init(color: color.opacity(0.0), location: 1)],
                                         startPoint: beamTop, endPoint: beamEnd))
                // 4) ÇEKİRDEK: ortada dar, parlak şerit
                cone(cx, lampY, endY, topW * 0.5, bottomW * 0.38)
                    .fill(LinearGradient(colors: [color.opacity(0.08), color.opacity(0.0)],
                                         startPoint: beamTop, endPoint: UnitPoint(x: 0.5, y: (lampY + endY) / 2 / total)))
                // 5) KENAR HATTI: koninin iki kenarı, aşağı doğru kaybolur
                edges(cx, lampY, endY, topW, bottomW)
                    .stroke(LinearGradient(colors: [color.opacity(0.16), color.opacity(0.0)], startPoint: beamTop, endPoint: beamEnd), lineWidth: 1)
            }
            .blendMode(.plusLighter)
            .opacity(fade)

            // 6) LAMBA: asma çubuğu + koyu gövde + parlayan mercek + hafif parlama
            Rectangle().fill(Color(white: 0.12))                                    // asma çubuğu
                .frame(width: 2, height: lampY - pivotY - 10)
                .position(x: cx, y: (pivotY + lampY - 10) / 2)
                .opacity(min(1, progress * 6))
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(LinearGradient(colors: [Color(white: 0.2), Color(white: 0.06)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 78, height: 24)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(white: 0.3), lineWidth: 0.5))
                Capsule().fill(color).frame(width: topW, height: 3.5).offset(y: 10)  // mercek
                    .opacity(0.25 + 0.55 * fade)
                Circle().fill(RadialGradient(colors: [color.opacity(0.3), color.opacity(0)], center: .center, startRadius: 0, endRadius: 26))
                    .frame(width: 52, height: 52).offset(y: 11)                        // parlama (glare)
                    .blendMode(.plusLighter)
                    .opacity(fade)
            }
            .position(x: cx, y: lampY - 10)
            .opacity(min(1, progress * 6)) // lamba ışıkla birlikte belirir
        }
    }

    // Koni: tepede dar (lamba), dipte geniş yamuk | Path [SWIFT]: noktalarla çizilen şekil
    private func cone(_ cx: CGFloat, _ top: CGFloat, _ bottom: CGFloat, _ topW: CGFloat, _ bottomW: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: cx - topW / 2, y: top))
            p.addLine(to: CGPoint(x: cx + topW / 2, y: top))
            p.addLine(to: CGPoint(x: cx + bottomW / 2, y: bottom))
            p.addLine(to: CGPoint(x: cx - bottomW / 2, y: bottom))
            p.closeSubpath()
        }
    }

    // Koninin yalnız iki yan kenarı (kenar hattı için)
    private func edges(_ cx: CGFloat, _ top: CGFloat, _ bottom: CGFloat, _ topW: CGFloat, _ bottomW: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: cx - topW / 2, y: top)); p.addLine(to: CGPoint(x: cx - bottomW / 2, y: bottom))
            p.move(to: CGPoint(x: cx + topW / 2, y: top)); p.addLine(to: CGPoint(x: cx + bottomW / 2, y: bottom))
        }
    }
}
