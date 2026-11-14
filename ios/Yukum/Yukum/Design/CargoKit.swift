//
//  CargoKit.swift
//  Yukum
//
//  Yük çeşitleri: meyve/sebze kasaları (portakal, limon, domates, avokado), zeytinyağı tenekesi ve şişesi, çuvallar, tek tek meyveler.
//  Hepsi kodla, basit şekillerden + kodla çizilmiş dokulardan kurulur (model/resim dosyası yok). Karton koli ayrı: Design/CardboardBoxKit.swift.
//

import RealityKit // [SWIFT] Apple'ın 3B motoru
import UIKit      // [SWIFT] UIColor, UIImage, resim çizici (UIGraphicsImageRenderer)

// ┌─ BAĞLANTI HARİTASI: CargoKit.swift ─────────────────────────────────────────
// │ GELEN     : Design/TruckLoadView.swift › TruckLoadRig.buildCargo (dorse: kasalar, teneke paleti, şişe paleti, çuval)
// │             (14 Kasım: giriş ekranında da denendi, kullanıcı kararıyla geri alındı → giriş ekranı yalnız karton koli)
// │ GİDEN     : Design/DesignPalette.swift (ürün renkleri) | Design/CardboardArt.swift › textureAsync (resmi dokuya çevirir, bekletmeden)
// │ TEKNİK    : RealityKit + Core Graphics. Her yük bir Entity: içinde birkaç parça (ahşap, meyve, metal...). Ölçüyü çağıran verir.
// │ REHBER    : Design/00_Rehber_Design.swift
// └──────────────────────────────────────────────────────────────────────
//
// KURULUM: CargoKit.prepared(palette:) → 4 doku (kabuk, avokado kabuğu, ahşap damarı, çuval bezi) ARKA PLANDA çizilir → malzemeler.
//   NEDEN async: doku çizimi pahalı; giriş ekranında ekranı dondurmasın (CardboardBoxKit.prepared ile aynı yöntem).
// KURAL (konum): her yük ortası (0,0,0) olan, verilen ölçüdeki kutuya sığar; TABANI y = -size.y/2'dedir (karton koli makeBox ile aynı sözleşme).
// NEDEN "birleştirilmiş şekil" (merged): bir kasada ~40 meyve + yaprak/sap var. Her biri ayrı Entity olsa dorsede binlerce parça olurdu;
//   eski telefon (iPhone 11) her parçayı ayrı çizer → yavaşlar. Bunun yerine AYNI şekli (ör. tek küre) bir şeklin içinde
//   çok kez, farklı yer/ölçü/dönüşle tekrarlarız (MeshResource "instance") → 40 portakal = TEK parça, tek çizim.
//   Kural: aynı malzemeyi paylaşan parçalar (tüm tahtalar, tüm portakal kabukları, tüm yapraklar) bir şekilde toplanır.
//
// GERÇEKÇİLİK (14 Kasım, kullanıcı: "meyve ve zeytinyağı çizimlerini ileri seviyede iyileştir"):
//   portakal : gözenekli kabuk dokusu + sap + bazılarında yaprak
//   limon    : uzunca gövde + iki ucunda sivri "meme" + bazılarında yaprak
//   domates  : hafif basık, çok parlak + üstte 5 kollu yeşil çanak + sap
//   avokado  : armut biçimi (iki küre), pütürlü koyu kabuk dokusu + sap
//   teneke   : kullanıcının 10 L görseli: düz parlak altın gövde, yuvarlak dikey kenarlar, taşan açık altın kenar kıvrımları, yassı koyu yeşil kapak + açık halka
//   şişe     : ŞEFFAF cam (omuz + boyun) içinde altın sarısı yağ, mantar tıpa (kullanıcının görselindeki gibi)

// Yük türleri
// ⮕ KULLANIM [CargoKind]: kullanır: TruckLoadRig › buildCargo
enum CargoKind: CaseIterable { // CaseIterable [SWIFT]: tüm durumları .allCases ile listeler
    case orangeCrate, lemonCrate, tomatoCrate, avocadoCrate // açık kasalar | ölçü yüksekse (> 0,5 m) üst üste 2 kasa, değilse 1
    case oliveOilTins                                       // palet üstünde iki kat teneke
    case oilBottles                                         // palet + tepsi üstünde iki kat şişe
    case sacks                                              // üst üste 3 çuval (un, bulgur, mercimek...)

    // Kasa ise içindeki meyve | kasa değilse nil
    var fruit: FruitKind? {
        switch self {
        case .orangeCrate: return .orange
        case .lemonCrate: return .lemon
        case .tomatoCrate: return .tomato
        case .avocadoCrate: return .avocado
        default: return nil
        }
    }
}

// Meyve türleri ve gerçek boyları (m) | sahne ölçeğinde biraz büyütülmüş: ekranda seçilsin
// ⮕ KULLANIM [FruitKind]: kullanır: CargoKind.fruit, CargoKit › crates
enum FruitKind: CaseIterable {
    case orange, lemon, tomato, avocado
    var size: Float {
        switch self {
        case .orange: return 0.13
        case .lemon: return 0.105
        case .tomato: return 0.12
        case .avocado: return 0.115
        }
    }
}

// ⮕ KULLANIM [CargoKit]: kullanır: TruckLoadRig › buildCargo, SceneRig › prepare
@MainActor
struct CargoKit {
    // MALZEMELER (renkler DesignPalette'te; dokular aşağıda kodla çizilir)
    private let wood, pallet, cardboard: PhysicallyBasedMaterial
    private let skins: [FruitKind: PhysicallyBasedMaterial]
    private let leaf, stem: PhysicallyBasedMaterial
    private let tinBody, tinRim, capGreen, spout: PhysicallyBasedMaterial
    private let sack, sackPrint, glass, oil, cork: PhysicallyBasedMaterial

    // TEMEL ŞEKİLLER: hepsi 1 birim; parçalar bunları ölçekleyerek kullanır (yeniden üretmeden)
    private let unitBox = MeshResource.generateBox(size: 1)
    // KÜRE: Apple'ın hazır küresi (generateSphere) çok sık örülü; bir kasada ~80 meyve × yansıma kopyası → ekranda yüz binlerce köşe.
    //   Ölçüm (14 Kasım, simülatör): yalnız kolilerle düşüşte 32 uzun kare, meyvelerle ~120. → Meyve boyunda fark edilmeyen SEYREK küre (16 × 10).
    private let unitSphere = CargoKit.lowPolySphere(segments: 16, rings: 10)
    private let unitCylinder = MeshResource.generateCylinder(height: 1, radius: 0.5)
    private let unitPillow = MeshResource.generateBox(size: 1, cornerRadius: 0.32) // çuval: köşeleri çok yuvarlak kutu, ölçeklenince "şişkin" görünür
    private let unitCan = MeshResource.generateBox(size: 1, cornerRadius: 0.1)     // teneke gövdesi: dikey kenarları hafif yuvarlak

    // BEKLETMEYEN KURULUM: dokular tek tek, aralarında ekrana sıra vererek üretilir.
    // ⮕ KULLANIM [prepared]: kullanır: TruckLoadRig › buildCargo, SceneBackground › RealityView.make
    static func prepared(palette: Palette) async -> CargoKit {
        // RESİMLER ARKA PLANDA ÇİZİLİR (14 Kasım gecikme düzeltmesi): projede her şey varsayılan olarak ana iş parçacığında (DefaultActorIsolation = MainActor);
        //   ~5000 nokta/çizgi çizmek giriş ekranını donduruyordu. Task.detached [SWIFT]: işi ana iş parçacığından AYRI çalıştırır; ekran bu sırada akar.
        //   Art fonksiyonları "nonisolated" → ana iş parçacığına bağlı değil, arka planda çağrılabilir.
        let images = await Task.detached(priority: .userInitiated) {
            (Art.peel(), Art.avocadoSkin(), Art.woodGrain(), Art.burlap())
        }.value
        let peel = await CardboardArt.textureAsync(from: images.0)            // ⮕ Design/CardboardArt.swift › textureAsync (dokuya çevirme de bekletmeden)
        let bumpy = await CardboardArt.textureAsync(from: images.1)
        let grain = await CardboardArt.textureAsync(from: images.2)
        let weave = await CardboardArt.textureAsync(from: images.3)
        return CargoKit(palette: palette, peel: peel, bumpy: bumpy, grain: grain, weave: weave)
    }

    private init(palette: Palette, peel: TextureResource?, bumpy: TextureResource?, grain: TextureResource?, weave: TextureResource?) {
        // Küçük yardımcı: renk (+ doku) + pürüzlülük (+ vernik, metal, saydamlık) → malzeme
        // Doku beyaz zemin üstüne gri izlerdir; renkle ÇARPILIR → aynı doku her tonda kullanılır (karton kolilerdeki yöntem).
        func material(_ color: UIColor, _ texture: TextureResource? = nil, rough: Float, coat: Float = 0, metal: Float = 0, opacity: Float = 1) -> PhysicallyBasedMaterial {
            var m = PhysicallyBasedMaterial()
            m.baseColor = texture.map { .init(tint: color, texture: .init($0)) } ?? .init(tint: color)
            m.roughness = .init(floatLiteral: rough)
            m.metallic = .init(floatLiteral: metal)
            if coat > 0 { m.clearcoat = .init(floatLiteral: coat); m.clearcoatRoughness = .init(floatLiteral: 0.05) } // [SWIFT] ince parlak vernik
            if opacity < 1 { m.blending = .transparent(opacity: .init(floatLiteral: opacity)) }                     // [SWIFT] yarı saydam
            return m
        }
        wood = material(palette.crateWood, grain, rough: 0.8)
        pallet = material(palette.palletWood, grain, rough: 0.85)
        cardboard = material(palette.boxColors[0], rough: 0.8)
        skins = [
            .orange: material(palette.orange, peel, rough: 0.45, coat: 0.5),   // portakal: gözenekli, hafif parlak
            .lemon: material(palette.lemon, peel, rough: 0.4, coat: 0.6),      // limon: gözenekli, parlak
            .tomato: material(palette.tomato, rough: 0.18, coat: 1.0),         // domates: pürüzsüz, ayna gibi parlak
            .avocado: material(palette.avocado, bumpy, rough: 0.85)            // avokado: pütürlü, mat
        ]
        leaf = material(palette.leaf, rough: 0.5, coat: 0.6)                   // yaprak: mumlu parlaklık
        stem = material(palette.stem, rough: 0.9)
        tinBody = material(palette.tinGold, rough: 0.16, coat: 1.0, metal: 0.55) // PÜRÜZSÜZ parlak altın (10 L görseli) | metal 0,55: koyu sahnede kararmasın (DesignPalette notu)
        tinRim = material(palette.tinRim, rough: 0.12, coat: 1.0, metal: 0.6)
        capGreen = material(palette.capGreen, rough: 0.3, coat: 0.6)           // plastik kapak ve sap
        spout = material(palette.spoutWhite, rough: 0.45, coat: 0.3)           // plastik ağız
        sack = material(palette.sack, weave, rough: 1.0)                       // çuval bezi: örgü dokusu, hiç parlamaz
        sackPrint = material(palette.sackPrint, rough: 0.9)
        glass = material(palette.glassTint, rough: 0.03, coat: 1.0, opacity: 0.22) // şeffaf cam: içindeki yağ görünür
        oil = material(palette.oil, rough: 0.05, coat: 1.0, opacity: 0.9)          // altın sarısı yağ
        cork = material(palette.cork, rough: 0.95)
    }

    // BU FONKSİYON: istenen türde, verilen ölçüde bir yük üretir.
    // ⮕ KULLANIM [make]: kullanır: TruckLoadRig › buildCargo, SceneRig › prepare (kalıp üretimi)
    func make(_ kind: CargoKind, size: SIMD3<Float>) -> Entity {
        switch kind {
        case .orangeCrate, .lemonCrate, .tomatoCrate, .avocadoCrate: return crates(size: size, fruit: kind.fruit!)
        case .oliveOilTins: return oilTins(size: size)
        case .oilBottles: return bottles(size: size)
        case .sacks: return sacks(size: size)
        }
    }

    // ─── MEYVE: gövde + ayrıntılar, meyvenin KENDİ ekseninde (frame: meyvenin sahnedeki yeri ve dönüşü) ───
    // Tüm kabuk parçaları küre (ölçek/kaydırma ile biçimlenir); yaprak ve çanak da yassı küre; sap silindir.
    struct FruitParts {
        var skins: [simd_float4x4] = [], greens: [simd_float4x4] = [], stems: [simd_float4x4] = []
        func entity(_ kit: CargoKit, _ kind: FruitKind) -> Entity {
            kit.group([(kit.unitSphere, skins, kit.skins[kind]!), (kit.unitSphere, greens, kit.leaf), (kit.unitCylinder, stems, kit.stem)])
        }
    }
    private func addFruit(_ kind: FruitKind, diameter d: Float, frame: simd_float4x4, into p: inout FruitParts) {
        // local: meyvenin kendi ekseninde bir parça (ölçek, dönüş, konum) → frame ile sahneye taşınır
        func local(_ scale: SIMD3<Float>, _ pos: SIMD3<Float> = .zero, _ rot: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0])) -> simd_float4x4 {
            frame * Transform(scale: scale, rotation: rot, translation: pos).matrix
        }
        func addLeaf(at top: Float) { // gövdenin tepesine yatık bir yaprak
            p.greens.append(local([d * 0.55, d * 0.05, d * 0.24], [d * 0.2, top, 0], simd_quatf(angle: 0.35, axis: [0, 0, 1])))
        }
        switch kind {
        case .orange:
            p.skins.append(local(SIMD3(repeating: d)))
            p.stems.append(local([d * 0.09, d * 0.06, d * 0.09], [0, d * 0.5, 0]))
            if Float.random(in: 0...1) < 0.25 { addLeaf(at: d * 0.5) }
        case .lemon: // uzun ekseni X: gövde + iki uçta sivri meme
            p.skins.append(local([d * 1.28, d, d]))
            for side: Float in [-1, 1] { p.skins.append(local([d * 0.3, d * 0.24, d * 0.24], [side * d * 0.66, 0, 0])) }
            if Float.random(in: 0...1) < 0.2 { addLeaf(at: d * 0.45) }
        case .tomato: // basık gövde + 5 kollu çanak + sap
            p.skins.append(local([d, d * 0.8, d]))
            for k in 0..<5 {
                let a = Float(k) * 2 * .pi / 5
                p.greens.append(local([d * 0.32, d * 0.035, d * 0.085], SIMD3(cos(a), 0, -sin(a)) * d * 0.12 + [0, d * 0.39, 0],
                                      simd_quatf(angle: a, axis: [0, 1, 0])))
            }
            p.stems.append(local([d * 0.07, d * 0.1, d * 0.07], [0, d * 0.44, 0]))
        case .avocado: // armut: büyük alt küre + küçük üst küre (uzun ekseni X) + sap
            p.skins.append(local([d * 1.05, d * 0.95, d * 0.95], [-d * 0.12, 0, 0]))
            p.skins.append(local(SIMD3(repeating: d * 0.72), [d * 0.38, d * 0.03, 0]))
            p.stems.append(local([d * 0.08, d * 0.1, d * 0.08], [d * 0.76, d * 0.03, 0], simd_quatf(angle: .pi / 2, axis: [0, 0, 1])))
        }
    }

    // ─── MEYVE KASALARI: açık tahta kasa(lar), içleri meyve dolu (en üstteki kasada meyve tepeleme) ───
    // TEK KASA (giriş ekranı, kullanıcı isteği: "kasaların içi görünsün"): çıtalar SEYREK ve ince (tek sıra, alçakta),
    //   meyveler %25 daha büyük ve kasanın dibinden ağzına kadar dolu, üstte tepeleme → kasa düşerken içi net görünür.
    private func crates(size s: SIMD3<Float>, fruit kind: FruitKind) -> Entity {
        var boards: [simd_float4x4] = []
        var fruits = FruitParts()
        let layers = s.y > 0.5 ? 2 : 1          // dorse hücresi uzun → üst üste 2 kasa | giriş ekranı → tek kasa
        let single = layers == 1
        let d = kind.size * (single ? 1.25 : 1)
        let stretch: Float = (kind == .lemon || kind == .avocado) ? 1.3 : 1 // uzunca meyveler ızgarada daha çok yer kaplar
        let h = (s.y - Float(layers - 1) * 0.02) / Float(layers) // bir kasanın yüksekliği
        for layer in 0..<layers {
            let y0 = -s.y / 2 + Float(layer) * (h + 0.02) // bu kasanın tabanı
            let isTop = layer == layers - 1
            boards.append(box([s.x, 0.025, s.z], at: [0, y0 + 0.0125, 0]))                     // taban
            let slats: [Float] = single ? [0.22] : [0.3, 0.75]  // yanlarda çıta sıraları (arası boşluklu) | tek kasada yalnız alçak bir sıra
            let slatH = h * (single ? 0.16 : 0.24)
            for k in slats {
                for side: Float in [-1, 1] {
                    boards.append(box([s.x, slatH, 0.022], at: [0, y0 + h * k, side * (s.z / 2 - 0.011)]))
                    boards.append(box([0.022, slatH, s.z], at: [side * (s.x / 2 - 0.011), y0 + h * k, 0]))
                }
            }
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {                               // 4 köşe dikmesi
                boards.append(box([0.045, h, 0.045], at: [sx * (s.x / 2 - 0.0225), y0 + h / 2, sz * (s.z / 2 - 0.0225)]))
            } }
            // Meyveler: ızgara gibi dizilir; her biri biraz farklı boyda, hafif kaymış ve farklı yöne dönük (elle doldurulmuş gibi)
            let nx = max(2, Int((s.x - 0.06) / (d * stretch))), nz = max(2, Int((s.z - 0.06) / d))
            let step = SIMD2<Float>((s.x - 0.06) / Float(nx), (s.z - 0.06) / Float(nz))
            let r = min(step.x / stretch, step.y) * 0.5
            let topY = isTop ? y0 + h - r * 0.3 : y0 + h - r * 1.1 // alttaki kasa: üstteki kasaya değmesin diye ağzın altında
            // Kat sayısı: tek kasada çıtalar seyrek → dipten ağza kadar dolu olmalı | dorsede yalnız üst kat görünür → tek kat yeter
            let fruitLayers = single ? max(1, Int((topY - (y0 + 0.025 + r)) / (r * 1.7)) + 1) : 1
            func place(_ pos: SIMD3<Float>) {
                let yaw = simd_quatf(angle: .random(in: 0...(2 * .pi)), axis: [0, 1, 0])
                let tilt = simd_quatf(angle: .random(in: -0.25...0.25), axis: [1, 0, 0]) // hafif yatık: hepsi aynı duruşta olmasın
                addFruit(kind, diameter: r * 2 * .random(in: 0.88...1.0), frame: Transform(rotation: yaw * tilt, translation: pos).matrix, into: &fruits)
            }
            for level in 0..<fruitLayers {
                let y = topY - Float(level) * r * 1.7
                let shift: Float = level.isMultiple(of: 2) ? 0 : 0.25 // alt katlar kaydırılır: gerçek istif gibi aralara oturur
                for i in 0..<nx { for j in 0..<nz {
                    place([-s.x / 2 + 0.03 + step.x * (Float(i) + 0.5 + shift) + .random(in: -0.01...0.01), y,
                           -s.z / 2 + 0.03 + step.y * (Float(j) + 0.5) + .random(in: -0.01...0.01)])
                } }
            }
            if isTop { // en üst kasada ikinci kat: ortası tepe yapar (tek kasada tam, dorsede seyrek)
                for i in 1..<nx { for j in 1..<nz where single || Bool.random() {
                    place([-s.x / 2 + 0.03 + step.x * Float(i), topY + r * 1.1, -s.z / 2 + 0.03 + step.y * Float(j)])
                } }
            }
        }
        let root = group([(unitBox, boards, wood)])
        root.addChild(fruits.entity(self, kind))
        return root
    }

    // ─── ZEYTİNYAĞI TENEKESİ: kullanıcının gösterdiği 10 L teneke görseli (14 Kasım, ikinci görsel; birebir buna göre) ───
    //   Gövde: DÜZ, pürüzsüz, parlak altın (kabartma, sap, dikiş YOK), dikey kenarlar yuvarlak, hafif dikdörtgen (eni boyundan dar)
    //   Üst ve alt: biraz taşan açık altın kenar kıvrımı (görselde ışığı yakalayan ince çizgi)
    //   Kapak: üst yüzde ön-sol köşeye yakın, ALÇAK ve yassı koyu yeşil yuvarlak kapak + altında ince açık (beyazımsı) halka
    // Parçalar türlerine göre ayrı listelerde toplanır → birden çok teneke de aynı 4 parçayla çizilir (paletteki 18 teneke = 4 parça).
    struct TinParts {
        var bodies: [simd_float4x4] = [], rims: [simd_float4x4] = [], rings: [simd_float4x4] = [], caps: [simd_float4x4] = []
        func entity(_ kit: CargoKit) -> Entity {
            kit.group([(kit.unitCan, bodies, kit.tinBody), (kit.unitCan, rims, kit.tinRim),
                       (kit.unitCylinder, rings, kit.spout), (kit.unitCylinder, caps, kit.capGreen)])
        }
    }
    private func addTin(_ t: SIMD3<Float>, at c: SIMD3<Float>, into p: inout TinParts) {
        p.bodies.append(box(t, at: c))                                         // gövde: düz parlak altın
        for side: Float in [-1, 1] {                                           // üst ve alt kenar kıvrımı: gövdeden biraz taşar
            p.rims.append(box([t.x * 1.025, t.y * 0.03, t.z * 1.025], at: c + [0, side * (t.y / 2 - t.y * 0.015), 0]))
        }
        let top = c.y + t.y / 2
        let capD = min(t.x, t.z) * 0.3
        let capX = c.x - t.x * 0.22, capZ = c.z + t.z * 0.16                    // ön-sol köşeye yakın (görseldeki yer)
        p.rings.append(cylinder(capD * 1.12, t.y * 0.012, at: [capX, top + t.y * 0.006, capZ])) // ince açık halka
        p.caps.append(cylinder(capD, t.y * 0.03, at: [capX, top + t.y * 0.012 + t.y * 0.015, capZ])) // yassı yeşil kapak
    }

    // ─── ZEYTİNYAĞI TENEKELERİ (dorse): palet + iki kat teneke ───
    private func oilTins(size s: SIMD3<Float>) -> Entity {
        var pallets: [simd_float4x4] = []
        var tins = TinParts()
        let baseY = palletParts(size: s, into: &pallets)
        let nx = 3, nz = 3
        let cellX = s.x / Float(nx), cellZ = s.z / Float(nz)
        let tinH = ((s.y / 2 - baseY) / 2 - 0.01) / 1.05 // 1,05: yassı kapak gövdenin üstüne biraz çıkar, üst kata değmesin
        let t = SIMD3<Float>(cellX * 0.88, tinH, cellZ * 0.88)
        for layer in 0..<2 { for i in 0..<nx { for j in 0..<nz {
            let c = SIMD3<Float>(-s.x / 2 + cellX * (Float(i) + 0.5), baseY + Float(layer) * (tinH * 1.05 + 0.01) + tinH / 2, -s.z / 2 + cellZ * (Float(j) + 0.5))
            addTin(t, at: c, into: &tins)
        } } }
        let root = group([(unitBox, pallets, pallet)])
        root.addChild(tins.entity(self))
        return root
    }

    // ─── ZEYTİNYAĞI ŞİŞESİ: şeffaf cam gövde + omuz + boyun, İÇİNDE altın sarısı yağ, mantar tıpa ───
    // NEDEN yağ ayrı parça: cam %22 opak → içindeki biraz daha dar yağ silindiri camın içinden görünür (gerçek şişe hissi).
    struct BottleParts {
        var glass: [simd_float4x4] = [], glassRound: [simd_float4x4] = [], oil: [simd_float4x4] = [], oilRound: [simd_float4x4] = [], corks: [simd_float4x4] = []
        func entity(_ kit: CargoKit) -> Entity {
            // Önce yağ, sonra cam: saydam parçalar arasında içteki önce çizilsin
            kit.group([(kit.unitCylinder, oil, kit.oil), (kit.unitSphere, oilRound, kit.oil), (kit.unitCylinder, corks, kit.cork),
                       (kit.unitCylinder, glass, kit.glass), (kit.unitSphere, glassRound, kit.glass)])
        }
    }
    private func addBottle(diameter dia: Float, height H: Float, floorY: Float, x: Float, z: Float, into p: inout BottleParts) {
        let bodyH = H * 0.55, shoulderH = H * 0.16, neckH = H * 0.2, corkH = H * 0.09
        p.glass.append(cylinder(dia, bodyH, at: [x, floorY + bodyH / 2, z]))                                           // gövde
        p.glassRound.append(Transform(scale: [dia, shoulderH * 2, dia], translation: [x, floorY + bodyH, z]).matrix)   // omuz: yarım küre gibi daralır
        p.glass.append(cylinder(dia * 0.32, neckH, at: [x, floorY + bodyH + shoulderH * 0.6 + neckH / 2, z]))          // boyun
        p.glass.append(cylinder(dia * 0.4, H * 0.025, at: [x, floorY + bodyH + shoulderH * 0.6 + neckH, z]))           // ağız halkası
        p.oil.append(cylinder(dia * 0.9, bodyH * 0.96, at: [x, floorY + bodyH * 0.49, z]))                             // yağ: gövdeyi doldurur
        p.oilRound.append(Transform(scale: [dia * 0.9, shoulderH * 1.4, dia * 0.9], translation: [x, floorY + bodyH * 0.97, z]).matrix) // yağ omza kadar
        p.corks.append(cylinder(dia * 0.3, corkH, at: [x, floorY + bodyH + shoulderH * 0.6 + neckH + corkH * 0.3, z]))  // mantar (boyna gömülü)
        p.corks.append(cylinder(dia * 0.36, corkH * 0.4, at: [x, floorY + bodyH + shoulderH * 0.6 + neckH + corkH * 0.85, z])) // mantarın taşan başı
    }

    // ─── ZEYTİNYAĞI ŞİŞELERİ (dorse): palet + iki kat şişe, katlar arasında karton tepsi ───
    private func bottles(size s: SIMD3<Float>) -> Entity {
        var pallets: [simd_float4x4] = [], trays: [simd_float4x4] = []
        var parts = BottleParts()
        let baseY = palletParts(size: s, into: &pallets)
        let nx = 3, nz = 4
        let cellX = s.x / Float(nx), cellZ = s.z / Float(nz)
        let layerH = (s.y / 2 - baseY) / 2
        let dia = min(cellX, cellZ) * 0.72
        for layer in 0..<2 {
            let floorY = baseY + Float(layer) * layerH
            trays.append(box([s.x * 0.98, 0.02, s.z * 0.98], at: [0, floorY + 0.01, 0]))            // karton tepsi
            for i in 0..<nx { for j in 0..<nz {
                addBottle(diameter: dia, height: layerH * 0.94, floorY: floorY + 0.02,
                          x: -s.x / 2 + cellX * (Float(i) + 0.5), z: -s.z / 2 + cellZ * (Float(j) + 0.5), into: &parts)
            } }
        }
        let root = group([(unitBox, pallets, pallet), (unitBox, trays, cardboard)])
        root.addChild(parts.entity(self))
        return root
    }

    // ─── ÇUVALLAR: üst üste 3 yatık çuval (örgü dokulu), biri hafif yamuk; üstlerinde kırmızı-kahve baskı bandı ───
    private func sacks(size s: SIMD3<Float>) -> Entity {
        var bags: [simd_float4x4] = [], prints: [simd_float4x4] = []
        let bagH = s.y / 3
        for layer in 0..<3 {
            let yaw = Float.random(in: -0.06...0.06)
            let c = SIMD3<Float>(.random(in: -0.02...0.02), -s.y / 2 + bagH * (Float(layer) + 0.5), .random(in: -0.02...0.02))
            bags.append(box([s.x * 0.94, bagH * 0.98, s.z * 0.9], at: c, yaw: yaw))
            prints.append(box([s.x * 0.4, 0.012, s.z * 0.34], at: c + [0, bagH * 0.47, 0], yaw: yaw)) // üst yüzdeki baskı
        }
        return group([(unitPillow, bags, sack), (unitBox, prints, sackPrint)])
    }

    // PALET: altta 3 kalas + üstte 5 tahta | tahtaların üst yüzünün yüksekliğini döndürür (yük oradan başlar)
    private func palletParts(size s: SIMD3<Float>, into parts: inout [simd_float4x4]) -> Float {
        let y0 = -s.y / 2
        for z: Float in [-1, 0, 1] { parts.append(box([s.x, 0.07, 0.08], at: [0, y0 + 0.035, z * (s.z / 2 - 0.04)])) }
        for k in 0..<5 { parts.append(box([s.x / 5 * 0.8, 0.025, s.z], at: [-s.x / 2 + s.x / 5 * (Float(k) + 0.5), y0 + 0.0825, 0])) }
        return y0 + 0.095
    }

    // ─── YARDIMCILAR ───
    // Birim şekli ölçek + dönüş + konuma çeviren dönüşüm (4×4 matris) | Transform [SWIFT]: ölçek/dönüş/konum üçlüsü
    private func box(_ size: SIMD3<Float>, at p: SIMD3<Float>, yaw: Float = 0) -> simd_float4x4 {
        Transform(scale: size, rotation: simd_quatf(angle: yaw, axis: [0, 1, 0]), translation: p).matrix
    }
    private func cylinder(_ diameter: Float, _ height: Float, at p: SIMD3<Float>) -> simd_float4x4 {
        Transform(scale: [diameter, height, diameter], translation: p).matrix
    }

    // BU FONKSİYON: her (temel şekil, konumlar, malzeme) üçlüsünü TEK parçaya çevirir ve hepsini bir Entity altında toplar.
    // MeshResource.Contents [SWIFT]: bir şeklin içi = "modeller" (geometri) + "örnekler" (instance: o modelin nereye, hangi ölçekle konduğu)
    // Aynı küreyi 40 farklı yere koymak = 1 model + 40 örnek → çizimde tek parça.
    fileprivate func group(_ parts: [(base: MeshResource, transforms: [simd_float4x4], material: PhysicallyBasedMaterial)]) -> Entity {
        let root = Entity()
        for part in parts where !part.transforms.isEmpty {
            guard let model = part.base.contents.models.first else { continue } // temel şeklin geometrisi
            var contents = MeshResource.Contents()
            contents.models = part.base.contents.models
            contents.instances = MeshInstanceCollection(part.transforms.enumerated().map { index, matrix in
                MeshResource.Instance(id: "i\(index)", model: model.id, at: matrix) // [SWIFT] aynı modelin bir kopyası, bu matrisle
            })
            guard let mesh = try? MeshResource.generate(from: contents) else { continue }
            root.addChild(ModelEntity(mesh: mesh, materials: [part.material]))
        }
        return root
    }

    // BU FONKSİYON: çapı 1 olan SEYREK küre üretir (enlem-boylam ızgarası). segments: boylam (yatay dilim), rings: enlem (dikey dilim).
    // MeshDescriptor [SWIFT]: kendi şeklimizi noktalar (positions), yüz yönleri (normals), doku koordinatları (textureCoordinates)
    //   ve üçgenlerle (primitives) tarif ederiz. 16 × 10 küre ≈ 190 nokta (hazır küreninin küçük bir kısmı).
    static func lowPolySphere(segments: Int, rings: Int) -> MeshResource {
        var positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], uvs: [SIMD2<Float>] = [], indices: [UInt32] = []
        for ring in 0...rings {
            let v = Float(ring) / Float(rings)
            let phi = v * .pi // 0 (tepe) → π (dip)
            for segment in 0...segments {
                let u = Float(segment) / Float(segments)
                let theta = u * 2 * .pi
                let n = SIMD3<Float>(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta)) // birim yön = yüzey normali
                positions.append(n * 0.5); normals.append(n); uvs.append([u, 1 - v])
            }
        }
        let row = UInt32(segments + 1)
        for ring in 0..<UInt32(rings) {
            for segment in 0..<UInt32(segments) {
                let a = ring * row + segment, b = a + row
                indices += [a, a + 1, b, b, a + 1, b + 1] // iki üçgen = bir dörtgen (dışarı bakan sırayla)
            }
        }
        var descriptor = MeshDescriptor(name: "lowPolySphere")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(uvs)
        descriptor.primitives = .triangles(indices)
        return (try? MeshResource.generate(from: [descriptor])) ?? .generateSphere(radius: 0.5) // olmazsa hazır küre
    }

    // ─── DOKULAR (kodla çizilen resimler) ───
    // Hepsi BEYAZ/açık gri zemin üstüne koyu ve açık izler: malzeme rengiyle çarpılınca o rengin gölgeli/parlak tonları olur.
    // Rastgelelik sabit tohumla değil: her açılışta desen biraz farklı, göz fark etmez.
    enum Art {
        // Portakal/limon kabuğu: binlerce minik gözenek (koyu nokta) + aralarda parlak benekler
        nonisolated static func peel() -> UIImage {
            draw { ctx, size in
                for _ in 0..<2200 { dot(ctx, size, radius: .random(in: 0.7...1.8), gray: .random(in: 0.72...0.88), alpha: 0.55) }
                for _ in 0..<500 { dot(ctx, size, radius: .random(in: 0.6...1.2), gray: 1, alpha: 0.7) }
            }
        }
        // Avokado kabuğu: iri pütürler (açık tepe + koyu çukur) → mat, engebeli görünüm
        nonisolated static func avocadoSkin() -> UIImage {
            draw(base: 0.82) { ctx, size in
                for _ in 0..<900 { dot(ctx, size, radius: .random(in: 1.5...3.5), gray: .random(in: 0.45...0.62), alpha: 0.6) }
                for _ in 0..<700 { dot(ctx, size, radius: .random(in: 1...2.5), gray: 1, alpha: 0.5) }
            }
        }
        // Ahşap damarı: dalgalı yatay çizgiler + birkaç budak
        nonisolated static func woodGrain() -> UIImage {
            draw(base: 0.92) { ctx, size in
                for line in stride(from: CGFloat(0), to: size, by: .random(in: 4...9)) {
                    let path = UIBezierPath()
                    let amp = CGFloat.random(in: 1...4), phase = CGFloat.random(in: 0...6)
                    path.move(to: CGPoint(x: 0, y: line))
                    for x in stride(from: CGFloat(0), through: size, by: 8) { path.addLine(to: CGPoint(x: x, y: line + sin(x / 30 + phase) * amp)) }
                    ctx.setStrokeColor(UIColor(white: .random(in: 0.6...0.8), alpha: 0.6).cgColor)
                    ctx.setLineWidth(.random(in: 0.8...2.2))
                    ctx.addPath(path.cgPath); ctx.strokePath()
                }
                for _ in 0..<3 { // budak
                    let c = CGPoint(x: .random(in: 0...size), y: .random(in: 0...size))
                    ctx.setFillColor(UIColor(white: 0.55, alpha: 0.7).cgColor)
                    ctx.fillEllipse(in: CGRect(x: c.x - 6, y: c.y - 3, width: 12, height: 6))
                }
            }
        }
        // Çuval bezi: kare örgü (yatay + dikey kalın lifler)
        nonisolated static func burlap() -> UIImage {
            draw(base: 0.85) { ctx, size in
                for i in stride(from: CGFloat(0), to: size, by: 4) {
                    ctx.setFillColor(UIColor(white: .random(in: 0.65...0.8), alpha: 0.5).cgColor)
                    ctx.fill(CGRect(x: 0, y: i, width: size, height: 1.6))
                    ctx.setFillColor(UIColor(white: .random(in: 0.95...1.0), alpha: 0.5).cgColor)
                    ctx.fill(CGRect(x: i, y: 0, width: 1.6, height: size))
                }
            }
        }

        // Ortak çizici: 256×256 açık zemin, üstüne verilen desen
        nonisolated private static func draw(base: CGFloat = 1, _ pattern: (CGContext, CGFloat) -> Void) -> UIImage {
            let size: CGFloat = 256
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1 // [SWIFT] ekran ölçeği değil, tam 256 piksel
            return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { context in
                let ctx = context.cgContext
                ctx.setFillColor(UIColor(white: base, alpha: 1).cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
                pattern(ctx, size)
            }
        }
        nonisolated private static func dot(_ ctx: CGContext, _ size: CGFloat, radius: CGFloat, gray: CGFloat, alpha: CGFloat) {
            let c = CGPoint(x: .random(in: 0...size), y: .random(in: 0...size))
            ctx.setFillColor(UIColor(white: gray, alpha: alpha).cgColor)
            ctx.fillEllipse(in: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
        }
    }
}
