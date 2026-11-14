//
//  CardboardArt.swift
//  Yukum
//
//  Koli yüzeyine giydirilen resimler (karton dokusu, baskılar, kargo etiketi). Hepsi kodla çizilir.
//

import RealityKit // [SWIFT] Apple'ın 3B motoru: şekil üretir, ışıklar, fizik hesaplar, kamerayla çizer (iOS'un içinde, ek kütüphane yok)
import UIKit      // [SWIFT] UIColor, UIImage ve resim çizici (UIGraphicsImageRenderer) buradan gelir

// ┌─ BAĞLANTI HARİTASI: CardboardArt.swift ─────────────────────────────────────────
// │ GELEN     : Design/BoxSceneBackground.buildScene → faceTexture(print:), labelTexture()
// │ GİDEN     : yok
// │ TEKNİK    : Core Graphics (UIGraphicsImageRenderer) ile resim çizilir → RealityKit TextureResource'a çevrilir.
// │ REHBER    : Design/00_Rehber_Design.swift (hangi teknik nerede, okuma sırası)
// └──────────────────────────────────────────────────────────────────────

// Koli yüzündeki baskı türleri.
enum CardboardPrint: CaseIterable {
    case plain    // baskısız
    case thisSideUp // "bu taraf yukarı" okları
    case fragile  // "kırılır" kadehi
}

// BU YAPI: koli yüzeyine giydirilen resimleri (doku) Core Graphics ile ÇİZER ve RealityKit dokusuna çevirir.
// NEDEN resim dosyası değil: dosya eklemeye gerek kalmaz, renk/baskı koddan ayarlanır, uygulama boyutu büyümez.
// ZİNCİR: buildScene → faceTexture(print:) → UIGraphicsImageRenderer ile 512×512 resim → TextureResource → malzemenin baseColor'ı.
// ⮕ KULLANIM [CardboardArt]: kullanır: SceneBackground › buildScene
@MainActor
enum CardboardArt {
    // Koli yüzü: beyaz zemin + karton lifleri + kenar kararması + (varsa) baskı.
    // İKİ ADIM, İKİ FONKSİYON (13 Kasım performans düzeltmesi):
    //   faceImage    = resmi ÇİZER (Core Graphics)           → hızlı
    //   texture(...) = resmi ekran kartı dokusuna ÇEVİRİR     → yavaş olan adım bu
    // Ayrı durdukları için çevirme adımının bekletmeyen (async) sürümü kullanılabiliyor: bkz. textureAsync, CardboardBoxKit.prepared
    static func faceTexture(print: CardboardPrint) -> TextureResource? { texture(from: faceImage(print: print)) }
    static func labelTexture() -> TextureResource? { texture(from: labelImage()) }

    // ⮕ KULLANIM [faceImage]: kullanır: faceTexture (bekleten yol) | CardboardBoxKit.prepared (bekletmeyen yol)
    static func faceImage(print: CardboardPrint) -> UIImage {
        let side: CGFloat = 512
        var rng = SeededRandom(seed: 0xC0FFEE) // SABİT TOHUM (15 Kasım): doku her açılışta aynı ⮕ Design/SeededRandom.swift
        return render(side: side) { context in
            let rect = CGRect(x: 0, y: 0, width: side, height: side)
            UIColor.white.setFill()
            context.fill(rect)

            // Karton lifleri: yüzlerce çok silik yatay çizgi → düz renk yerine "kâğıt" dokusu.
            for _ in 0..<1400 {
                let y = CGFloat.random(in: 0...side, using: &rng)
                let x = CGFloat.random(in: 0...side, using: &rng)
                let dark = Bool.random(using: &rng)
                context.setStrokeColor((dark ? UIColor.black : UIColor.white).withAlphaComponent(.random(in: 0.012...0.035, using: &rng)).cgColor)
                context.setLineWidth(.random(in: 0.6...1.6, using: &rng))
                context.move(to: CGPoint(x: x, y: y))
                context.addLine(to: CGPoint(x: x + .random(in: 30...160, using: &rng), y: y + .random(in: -1...1, using: &rng)))
                context.strokePath()
            }
            // Oluklu mukavva izi: düzenli aralıklı çok silik dikey şeritler.
            for column in stride(from: CGFloat(0), to: side, by: 9) {
                context.setFillColor(UIColor.black.withAlphaComponent(0.008).cgColor)
                context.fill(CGRect(x: column, y: 0, width: 3, height: side))
            }
            // Kenar kararması: kenarlara doğru koyulaşan çerçeveler → köşeler yıpranmış/gölgeli görünür, kutu "hacimli" durur.
            for step in 0..<26 {
                let t = 1 - CGFloat(step) / 26
                context.setStrokeColor(UIColor.black.withAlphaComponent(0.16 * t * t).cgColor)
                context.setLineWidth(5)
                context.stroke(rect.insetBy(dx: CGFloat(step) * 3.2, dy: CGFloat(step) * 3.2))
            }

            // Baskı: koyu kahve mürekkep (yarı saydam siyah, tint ile çarpılınca kahveye döner).
            let ink = UIColor.black.withAlphaComponent(0.5)
            func symbol(_ name: String, at origin: CGPoint, size: CGFloat) {
                let configuration = UIImage.SymbolConfiguration(pointSize: size, weight: .bold)
                UIImage(systemName: name, withConfiguration: configuration)?
                    .withTintColor(ink, renderingMode: .alwaysOriginal)
                    .draw(at: origin)
            }
            switch print {
            case .plain:
                break
            case .thisSideUp:
                symbol("arrow.up", at: CGPoint(x: 330, y: 60), size: 62)
                symbol("arrow.up", at: CGPoint(x: 400, y: 60), size: 62)
                context.setFillColor(ink.cgColor)
                context.fill(CGRect(x: 328, y: 150, width: 140, height: 9))
            case .fragile:
                symbol("wineglass", at: CGPoint(x: 370, y: 56), size: 78)
            }
            if print != .plain { // marka baskısı: sol alt köşe
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 34, weight: .heavy),
                    .foregroundColor: ink,
                    .kern: 5
                ]
                ("YÜKÜM" as NSString).draw(at: CGPoint(x: 46, y: 420), withAttributes: attributes)
            }
        }
    }

    // Kargo etiketi: beyaz kâğıt + barkod + adres satırları.
    // ⮕ KULLANIM [labelImage]: kullanır: labelTexture | CardboardBoxKit.prepared
    static func labelImage() -> UIImage {
        let width: CGFloat = 390, height: CGFloat = 256
        var rng = SeededRandom(seed: 0xBA5C0DE) // SABİT TOHUM: barkod hep aynı
        return render(side: width, height: height) { context in
            UIColor(white: 0.97, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.setFillColor(UIColor(white: 0.1, alpha: 1).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: 44)) // üst siyah bant
            var x: CGFloat = 26
            while x < width - 30 { // barkod: rastgele kalınlıkta dikey çizgiler
                let bar = CGFloat.random(in: 2...8, using: &rng)
                context.fill(CGRect(x: x, y: 150, width: bar, height: 80))
                x += bar + .random(in: 2...6, using: &rng)
            }
            context.setFillColor(UIColor(white: 0.35, alpha: 1).cgColor)
            for (row, lineWidth) in [CGFloat(230), 170, 200].enumerated() { // adres satırları
                context.fill(CGRect(x: 26, y: 64 + CGFloat(row) * 24, width: lineWidth, height: 9))
            }
        }
    }

    private static func render(side: CGFloat, height: CGFloat? = nil, draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1     // tam 512 piksel (ekran yoğunluğuyla çarpma)
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: height ?? side), format: format)
            .image { draw($0.cgContext) }
    }

    private static func texture(from image: UIImage) -> TextureResource? {
        guard let cgImage = image.cgImage else { return nil }
        return try? TextureResource(image: cgImage, options: .init(semantic: .color)) // [SWIFT] resmi ekran kartı dokusuna çevir
    }

    // textureAsync: aynı çevirme, ama BEKLETMEDEN | await [SWIFT]: iş bitene kadar bu fonksiyon durur, ANA İŞ PARÇACIĞI durmaz
    // NEDEN: yukarıdaki texture(from:) çevirme bitene kadar ekranı kilitler (dokunuş algılanmaz, animasyon donar).
    //   Bu sürümde ağır iş RealityKit'in arka plan işçisinde yapılır; giriş ekranı o sırada çizilmeye ve dokunuşa cevap vermeye devam eder.
    // ⮕ KULLANIM [textureAsync]: kullanır: CardboardBoxKit.prepared
    static func textureAsync(from image: UIImage) async -> TextureResource? {
        guard let cgImage = image.cgImage else { return nil }
        return try? await TextureResource(image: cgImage, withName: nil, options: .init(semantic: .color))
    }
}
