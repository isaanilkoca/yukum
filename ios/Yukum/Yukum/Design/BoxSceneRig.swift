//
//  BoxSceneRig.swift
//  Yukum
//
//  Kolileri sırayla düşüren, yansımalarını eşitleyen, yığın durunca sahneyi donduran ve en sonda spot ışığını açan nesne.
//

import RealityKit // [SWIFT] Apple'ın 3B motoru: şekil üretir, ışıklar, fizik hesaplar, kamerayla çizer (iOS'un içinde, ek kütüphane yok)
import UIKit      // [SWIFT] UIColor, UIImage ve resim çizici (UIGraphicsImageRenderer) buradan gelir

// ┌─ BAĞLANTI HARİTASI: BoxSceneRig.swift ─────────────────────────────────────────
// │ GELEN     : Design/BoxSceneBackground.swift → sahne kurulurken prepare(kit:), sonra her karede tick()
// │ GİDEN     : Design/CardboardBoxKit.swift (koli) | Design/DesignPalette.swift (spot ışığı rengi/gücü)
// │             onSettled kapanışı → Design/TapedBoxBackground.wrapScreen (bantlamayı başlatır)
// │             onFinished kapanışı → Design/BoxSceneBackground (kare aboneliğini kapatır)
// │ TEKNİK    : RealityKit fizik (PhysicsBodyComponent + CollisionComponent) + SpotLightComponent.
// │ REHBER    : Design/00_Rehber_Design.swift (hangi teknik nerede, okuma sırası)
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: kolileri sırayla sahneye bırakır, her karede yansıma kopyalarını asıllarıyla eşitler, yığın durunca her şeyi dondurur.
// NEDEN class: kare aboneliği bir closure; struct kopyalanırdı, class aynı nesneyi paylaşır.
//
// ÖMÜR (koliler YALNIZ BİR KEZ düşer; bu bir oyun değil, arka plan):
//   1. prepare(kit:)      sahne kurulurken: birkaç KALIP koli üretilir (pahalı iş burada, bir kez) + ekran kartı ısıtılır
//   2. tick()             her karede: zamanı gelen koli kalıptan KOPYALANIP bırakılır (ucuz) → fizik motoru düşürür
//   3. onSettled          son koliden 1,7 sn sonra: bantlar başlar
//   4. freeze()           yığın gerçekten durunca: fizik kapatılır, kare aboneliği bırakılır
//   5. revealSpotlight()  en son: tepeden spot ışığı ORTADA küçük bir daire olarak yanar, dairesi giderek BÜYÜYÜP tüm kolileri kaplar
//
// 14 Kasım KARARI (kullanıcı): giriş ekranında YALNIZ karton koli düşer (meyve/teneke/şişe denendi, geri alındı; onlar dorsede: Design/CargoKit.swift).
//   Tek yenilik spot ışığı.
//
// PERFORMANS NOTLARI (13-14 Kasım, gerçek cihazda takılma görülünce):
//   KALIP + KOPYA : eskiden her koli bırakılırken şekli (köşesi yuvarlak kutu + bant + kapak + etiket) sıfırdan üretiliyordu.
//                   Ölçüm: 24 koliyi üretmek ≈ 190 ms, 24 koliyi KOPYALAMAK ≈ 2 ms (simülatörde). Şimdi kalıplar önceden üretilir.
//                   Kopya, şekil ve malzemeyi PAYLAŞIR (yeniden üretmez) → hem hızlı hem bellekte az yer.
//   ISINMA        : ekran kartı bir malzemeyi İLK KEZ çizerken onun programını derler (o kare uzar). Kalıplar düşüş başlamadan
//                   görünmeyecek kadar küçük bir kez çizdirilir → derleme ekran sakinken yapılır (ölçüm: ilk düşüş takılması kalktı).
//   DONDURMA      : yığın durunca fizik ve yansıma eşitleme biter → sahne duran bir resimdir (pil/işlemci boşa harcanmaz).
// ⮕ KULLANIM [SceneRig]: kullanır: SceneBackground › rig
@MainActor
final class SceneRig {
    static let halfWidth: Float = 1.75   // yığının yarı genişliği (m) ≈ ekranın yarısı
    static let halfDepth: Float = 0.75   // yığının yarı derinliği (m): dar tutulur ki koliler YUKARI yığılsın
    static let boxCount = 24             // toplam koli
    static let templateCount = 8         // kalıp sayısı: 8 farklı ölçü/renk, 24 koliye dağılır (göz tekrarı fark etmez)
    static let spawnInterval: Float = 0.11 // iki koli arası bekleme (sn) → hepsi birden değil, yağmur gibi

    var root: Entity?
    var mirrorRoot: Entity?
    var keyLight: Entity?         // sahnenin ana ışığı: spot yanınca kısılır (BoxSceneBackground verir)
    var palette: Palette?         // spot ışığının rengi ve gücü
    var onSettled: (() -> Void)?  // son koliden 1,7 sn sonra, 1 kez → bantlar
    var onFinished: (() -> Void)? // yığın tamamen durunca, 1 kez → kare aboneliği kapanır
    private var settledFired = false
    private var finished = false

    // Kalıp: sahneye EKLENMEYEN hazır koli + onun çarpışma şekli. Sahneye giren koliler bunların kopyasıdır.
    private var templates: [(box: ModelEntity, shape: ShapeResource)] = []
    private var pairs: [(box: Entity, reflection: Entity)] = [] // asıl koli ↔ zemindeki yansıma kopyası
    private var time: Float = 0
    private var nextSpawn: Float = 0.5 // ilk koli ekran açıldıktan yarım saniye sonra
    private var stillFrames = 0        // art arda kaç karedir hiçbir koli kıpırdamadı
    private var maxFrame: Float = 0    // GEÇİCİ ölçüm: düşüş boyunca en uzun kare (sn) → donunca App/PerfLog'a yazılır

    // BU FONKSİYON: kalıp kolileri üretir. Pahalı iş (şekil üretimi) burada, koliler düşmeye başlamadan ÖNCE yapılır.
    // await Task.yield() [SWIFT]: "sıramı bir anlığına bırakıyorum" → her kalıptan sonra ekran bir kare çizebilir, dokunuş işlenebilir.
    // ⮕ KULLANIM [prepare]: kullanır: SceneBackground › RealityView.make (1 kez)
    func prepare(kit: CardboardBoxKit) async {
        for _ in 0..<Self.templateCount {
            // Rastgele ölçü: gerçek koliler gibi kimi küp, kimi yassı, kimi uzun.
            let size = SIMD3<Float>(.random(in: 0.55...0.95), .random(in: 0.40...0.75), .random(in: 0.50...0.80))
            templates.append((kit.makeBox(size: size), .generateBox(size: size))) // bantlı, etiketli hazır koli: Design/CardboardBoxKit.swift
            await Task.yield()
        }

        // ISINMA: her kalıbın bir kopyası kameranın önünde, 1/1000 boyunda birkaç kare çizilir, sonra silinir (yukarıdaki not).
        //   NEDEN gizli (isEnabled = false) değil: gizli parça hiç çizilmez → derleme de yapılmaz.
        guard let root else { return }
        let warmRoot = Entity()
        warmRoot.position = [0, 3, 2] // kameranın görüş alanının ortası
        for template in templates {
            let copy = template.box.clone(recursive: true)
            copy.scale = SIMD3(repeating: 0.001)
            warmRoot.addChild(copy)
        }
        root.addChild(warmRoot)
        try? await Task.sleep(for: .milliseconds(150)) // birkaç kare çizilsin
        warmRoot.removeFromParent()
    }

    // ⮕ KULLANIM [tick]: kullanır: SceneBackground › SceneEvents.Update aboneliği (her kare)
    func tick(deltaTime: Float) {
        guard !finished else { return } // donduktan sonra yapılacak iş yok
        time += deltaTime
        if !pairs.isEmpty { maxFrame = max(maxFrame, deltaTime) } // GEÇİCİ ölçüm: düşüş başladıktan sonraki en uzun kare

        // SIRAYLA BIRAK: zamanı gelince bir koli daha ekle (toplam boxCount olana kadar).
        while pairs.count < Self.boxCount, time >= nextSpawn {
            spawnBox()
            nextSpawn += Self.spawnInterval
        }

        // DURDU MU (bantlar için): son koli bırakıldıktan 1,7 sn sonra yığın yerleşmiş sayılır → dinleyene 1 kez haber ver.
        // NEDEN sahne saatiyle: yavaş telefonda sahne de yavaş akar; duvar saatiyle beklesek bant erken gelirdi.
        if !settledFired, pairs.count == Self.boxCount, time >= nextSpawn + 1.7 {
            settledFired = true
            onSettled?()
        }

        // YANSIMAYI EŞİTLE: fizik motoru asıl koliyi oynatır; kopyaya aynı konum/dönüşü veriyoruz.
        // Kopyalar ters çevrilmiş atanın (mirrorRoot) içinde olduğu için zeminin altında baş aşağı görünür.
        // Aynı döngüde ÖLÇÜYORUZ: yansıma bir önceki karedeki konumu taşıyor → asılla arasındaki fark = kolinin bu karede gittiği yol.
        var maxMove: Float = 0
        for pair in pairs {
            maxMove = max(maxMove, simd_distance(pair.reflection.position, pair.box.position)) // simd_distance [SWIFT]: iki nokta arası uzaklık
            pair.reflection.transform = pair.box.transform
        }

        // GERÇEKTEN DURDU MU (dondurma için): bütün koliler bırakıldıysa ve 45 kare (~0,75 sn) boyunca en çok oynayan koli bile
        // yarım milimetreden az gittiyse yığın durmuştur. Emniyet: son koliden 8 sn sonra ne olursa olsun dondur (titreyen bir koli sahneyi sonsuza dek açık tutmasın).
        guard pairs.count == Self.boxCount else { return }
        stillFrames = maxMove < 0.0005 ? stillFrames + 1 : 0
        if stillFrames >= 45 || time >= nextSpawn + 8 { freeze() }
    }

    // BU FONKSİYON: yığını olduğu yerde sabitler. Koliler bir daha hareket etmez; dokunuşla da zıplamaz (bilerek: giriş ekranı oyun değil).
    // Fizik bileşenleri SİLİNİR: motor artık bu kolileri hiç hesaplamaz. Koliler son konumlarında görüntü olarak kalır. Sonra spot yanar.
    // ⮕ KULLANIM [freeze]: kullanır: tick
    private func freeze() {
        finished = true
        for pair in pairs {
            pair.box.components.remove(PhysicsBodyComponent.self)
            pair.box.components.remove(CollisionComponent.self)
        }
        templates.removeAll() // kalıplara artık gerek yok
        PerfLog.mark("giriş sahnesi: yığın durdu | en uzun kare \(Int(maxFrame * 1000)) ms (60 fps = 16 ms)") // GEÇİCİ ölçüm ⮕ App/PerfLog.swift
        onFinished?()
        revealSpotlight()
    }

    // BU FONKSİYON: her şey düştükten sonra tepeden spot ışığını açar. ORTADAN YAYILARAK (14 Kasım, kullanıcı isteği):
    //   ışık önce yığının ortasında küçük bir daire olarak yanar, dairesi 2 sn içinde giderek büyür ve tüm kolileri kaplar.
    //   NASIL: SpotLightComponent'in koni açısı (outerAngle) her adımda büyütülür: 3° → 30°.
    //   KESKİN KENAR: iç açı dış açıdan yalnız 3° küçük → dairenin kenarı bulanık değil, net çizgi (sahne ışığı gibi).
    //   YAVAŞLAYARAK: büyüme "ease-out" (1 - (1-k)³) → başta hızlı açılır, kenara yaklaşınca yavaşlar.
    //   Aynı anda ana ışık %40a kısılır → ışık dairesinin dışı loş kalır, dairenin içindeki koliler parlak ve canlı öne çıkar.
    //   NEDEN Task + bekleme (kare aboneliği değil): abonelik dondurmada kapandı; kısa bir geçiş için yeniden açmaya değmez.
    // ⮕ KULLANIM [revealSpotlight]: kullanır: freeze
    private func revealSpotlight() {
        guard let root, let palette, palette.isDark else { return } // YALNIZ KOYU MOD (14 Kasım, kullanıcı kararı): gündüzde spot ve kısma yok
        let spot = Entity()
        var light = SpotLightComponent(color: palette.spotColor, intensity: 0,
                                       innerAngleInDegrees: 1, outerAngleInDegrees: 3, attenuationRadius: 30)
        spot.components.set(light)
        spot.look(at: [0, 1.2, 0], from: [0, 11, 3], relativeTo: nil) // tam tepeden, hafif önden, yığının ortasına
        root.addChild(spot)

        let keyStart = keyLight?.components[DirectionalLightComponent.self]
        Task { @MainActor in
            let steps = 60 // 60 adım × 33 ms ≈ 2 sn
            for step in 1...steps {
                let k = Float(step) / Float(steps)
                let eased = 1 - pow(1 - k, 3)                              // ease-out: hızlı başla, yavaş bitir
                light.outerAngleInDegrees = 3 + 27 * eased                  // 3° → 30°: daire büyür
                light.innerAngleInDegrees = light.outerAngleInDegrees - 3   // keskin kenar
                light.intensity = palette.spotIntensity * min(1, k * 4)     // ilk 0,5 sn'de tam güce çıkar
                spot.components.set(light)
                if let start = keyStart {
                    var key = start
                    key.intensity = start.intensity * (1 - 0.6 * eased)     // ana ışık %100 → %40 (koni dışı karanlık; karartma perdesiyle birlikte: Design/SpotBeam)
                    keyLight?.components.set(key)
                }
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    // ⮕ KULLANIM [spawnBox]: kullanır: tick
    private func spawnBox() {
        guard let root, let mirrorRoot, let template = templates.randomElement() else { return }

        // KALIPTAN KOPYA: clone(recursive:) [SWIFT] koliyi çocuklarıyla (bant, kapak, etiket) kopyalar; şekil ve malzeme paylaşılır.
        let box = template.box.clone(recursive: true)

        // Başlangıç: ekranın üstünde rastgele bir noktada, rastgele eğik.
        box.position = [.random(in: -Self.halfWidth + 0.5...Self.halfWidth - 0.5),
                        .random(in: 7.5...9.5),
                        .random(in: -Self.halfDepth + 0.4...Self.halfDepth - 0.4)]
        box.orientation = simd_quatf(angle: .random(in: 0...(.pi)), axis: simd_normalize([.random(in: -1...1), 1, .random(in: -1...1)]))

        // FİZİK: iki bileşen yeter.
        box.components.set(CollisionComponent(shapes: [template.shape])) // "şeklim bu, çarpışırım" | şekil de kalıpla birlikte hazır
        var body = PhysicsBodyComponent(massProperties: .default,
                                        material: .generate(friction: 0.7, restitution: 0.12), // sürtünme yüksek, zıplama az → karton hissi
                                        mode: .dynamic) // dynamic = yerçekimi ve çarpışmayla hareket eder
        body.angularDamping = 0.5 // dönmeyi söndür → koliler topaç gibi dönmez, çabuk durulur
        body.linearDamping = 0.05
        box.components.set(body)
        root.addChild(box)

        // Yansıma kopyası: aynı kalıptan ikinci kopya; fizik bileşeni hiç takılmaz, yalnız görüntü.
        let reflection = template.box.clone(recursive: true)
        reflection.transform = box.transform
        mirrorRoot.addChild(reflection)

        pairs.append((box, reflection))
    }
}
