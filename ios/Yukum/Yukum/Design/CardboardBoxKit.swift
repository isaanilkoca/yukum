//
//  CardboardBoxKit.swift
//  Yukum
//
//  Koli üreten takım: malzemeleri bir kez hazırlar, istenen ölçüde bantlı/etiketli 3B koli verir.
//

import RealityKit // [SWIFT] Apple'ın 3B motoru (iOS'un içinde, ek kütüphane yok)
import UIKit      // [SWIFT] UIColor buradan gelir

// ┌─ BAĞLANTI HARİTASI: CardboardBoxKit.swift ─────────────────────────────────────────
// │ GELEN     : Design/BoxSceneBackground.swift (giriş ekranındaki düşen koliler) | Design/TruckLoadView.swift (kasaya dizilen koliler)
// │ GİDEN     : Design/CardboardArt.swift (karton dokusu, etiket resmi) | Design/DesignPalette.swift (koli renkleri)
// │ REHBER    : Design/00_Rehber_Design.swift
// └──────────────────────────────────────────────────────────────────────

// NEDEN ayrı takım: koli iki ayrı sahnede kullanılıyor (düşen yığın + kamyon kasası). Koli tarifi tek yerde durursa
//   ikisi de aynı görünür ve bir değişiklik (bant rengi, köşe yuvarlaklığı) iki sahneye birden yansır.
// NEDEN malzemeler bir kez üretilir: malzeme/doku üretmek pahalıdır; 24 koli için 24 kez üretmek yerine 12 malzeme paylaşılır.
// ⮕ KULLANIM [CardboardBoxKit]: kullanır: SceneBackground › buildScene, TruckLoadRig
@MainActor
struct CardboardBoxKit {
    private var materials: [PhysicallyBasedMaterial] = []   // karton yüzeyler: (renk × baskı) çiftleri
    private var tapeMaterial = PhysicallyBasedMaterial()    // koli bandı
    private var labelMaterial: PhysicallyBasedMaterial?     // kargo etiketi (doku üretilemezse etiket konmaz)
    private let seamMaterial = UnlitMaterial(color: UIColor(red: 0.30, green: 0.20, blue: 0.11, alpha: 1)) // kapak yarığı: koyu kahve

    // BEKLETEN KURULUM: dokular hemen, ekranı kilitleyerek üretilir. Kullanan: Design/TruckLoadView (prototip).
    init(palette: Palette) {
        self.init(palette: palette,
                  textures: CardboardPrint.allCases.compactMap { CardboardArt.faceTexture(print: $0) },
                  labelTexture: CardboardArt.labelTexture())
    }

    // BEKLETMEYEN KURULUM (13 Kasım performans düzeltmesi): giriş ekranı bunu kullanır.
    // SORUN: gerçek cihazda (iPhone 11) giriş ekranı açılırken ~1 sn'lik takılma uyarısı çıkıyordu. Ölçümde sahne kurulumunun
    //   en büyük tek parçası doku üretimiydi ve hepsi tek seferde, ana iş parçacığında yapılıyordu.
    // ÇÖZÜM: her doku ayrı ayrı ve bekletmeden üretilir (CardboardArt.textureAsync). Aradaki her await'te ekran nefes alır.
    // static func [SWIFT]: nesneye değil türe ait fonksiyon → CardboardBoxKit.prepared(palette:) diye çağrılır
    // NEDEN init değil: bu yapının init'i zaten var (yukarıda); "aynı şeyin async yolu" ayrı adla durunca çağıran hangisini seçtiğini görür.
    // ⮕ KULLANIM [prepared]: kullanır: SceneBackground › RealityView.make
    static func prepared(palette: Palette) async -> CardboardBoxKit {
        var textures: [TextureResource] = []
        for print in CardboardPrint.allCases {
            if let texture = await CardboardArt.textureAsync(from: CardboardArt.faceImage(print: print)) { textures.append(texture) }
        }
        let label = await CardboardArt.textureAsync(from: CardboardArt.labelImage())
        return CardboardBoxKit(palette: palette, textures: textures, labelTexture: label)
    }

    // Ortak kurulum: dokular HAZIR gelir, burada yalnız malzemeler birleştirilir (hızlı). İki yol da buraya düşer → malzeme tarifi tek yerde.
    private init(palette: Palette, textures: [TextureResource], labelTexture: TextureResource?) {
        // Doku beyaz zemin üstüne gri izlerdir; baseColor tint'i ile ÇARPILIR → aynı doku her karton tonunda kullanılır.
        for color in palette.boxColors {
            for texture in textures {
                var material = PhysicallyBasedMaterial() // [SWIFT] fizik tabanlı malzeme: ışığa gerçek yüzey gibi tepki verir
                material.baseColor = .init(tint: color, texture: .init(texture)) // [SWIFT] renk × doku
                material.roughness = 0.55                               // karton: saten (ayna gibi değil)
                material.metallic = 0.0
                material.clearcoat = .init(floatLiteral: 0.3)           // [SWIFT] üstte ince vernik: ışıkta hafif parlar
                material.clearcoatRoughness = .init(floatLiteral: 0.25)
                materials.append(material)
            }
        }
        if let labelTexture { // beyaz kargo etiketi (barkodlu)
            var label = PhysicallyBasedMaterial()
            label.baseColor = .init(tint: .white, texture: .init(labelTexture))
            label.roughness = 0.4
            labelMaterial = label
        }
        tapeMaterial.baseColor = .init(tint: palette.tape)
        tapeMaterial.roughness = 0.15
        tapeMaterial.clearcoat = .init(floatLiteral: 1.0)
    }

    // BU FONKSİYON: verilen ölçüde (metre) bir koli üretir. Konum, dönüş ve fizik EKLEMEZ; onları çağıran sahne verir.
    // ⮕ KULLANIM [makeBox]: kullanır: SceneRig › spawnBox, TruckLoadRig › buildCargo
    func makeBox(size: SIMD3<Float>) -> ModelEntity {
        let box = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.045), // [SWIFT] yuvarlatılmış köşeli kutu
                              materials: [materials.randomElement() ?? PhysicallyBasedMaterial()])

        // Koli bandı: üst yüzün ortasından geçen ince parlak şerit (kolinin çocuğu → onunla birlikte döner).
        let tape = ModelEntity(mesh: .generateBox(size: [size.x * 0.22, 0.012, size.z * 1.002], cornerRadius: 0.004),
                               materials: [tapeMaterial])
        tape.position.y = size.y / 2
        box.addChild(tape)
        // Bandın ön ve arka yüze sarkan uçları (gerçek kolide bant kenardan aşağı kıvrılır).
        for side: Float in [-1, 1] {
            let flap = ModelEntity(mesh: .generateBox(size: [size.x * 0.22, size.y * 0.32, 0.012], cornerRadius: 0.004),
                                   materials: [tapeMaterial])
            flap.position = [0, size.y / 2 - size.y * 0.16, side * size.z / 2]
            box.addChild(flap)
        }
        // Kapak birleşim çizgisi: üst yüzde bandın altından geçen ince koyu yarık (iki kapağın birleştiği yer).
        let seam = ModelEntity(mesh: .generateBox(size: [size.x * 1.001, 0.004, 0.012]), materials: [seamMaterial])
        seam.position.y = size.y / 2
        box.addChild(seam)

        // Kargo etiketi: kolilerin yarısında, ön yüzün köşesine yapışık beyaz barkodlu etiket.
        if let labelMaterial, Bool.random(), size.x > 0.45, size.y > 0.3 {
            let label = ModelEntity(mesh: .generateBox(size: [0.26, 0.17, 0.006], cornerRadius: 0.003), materials: [labelMaterial])
            label.position = [size.x / 2 - 0.19, -size.y / 2 + 0.15, size.z / 2]
            box.addChild(label)
        }
        return box
    }
}
