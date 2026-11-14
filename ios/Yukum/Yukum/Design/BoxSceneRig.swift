//
//  BoxSceneRig.swift
//  Yukum
//
//  Kolileri sırayla düşüren, yığın durunca sahneyi donduran ve en sonda spot ışığını açan nesne.
//

import RealityKit // [SWIFT] Apple'ın 3B motoru: şekil üretir, ışıklar, fizik hesaplar, kamerayla çizer (iOS'un içinde, ek kütüphane yok)
import UIKit      // [SWIFT] UIColor, UIImage ve resim çizici (UIGraphicsImageRenderer) buradan gelir
import Combine    // [SWIFT] Cancellable: kare aboneliğini tutup kapatmak için (StillScene/ARView yolu)

// ┌─ BAĞLANTI HARİTASI: BoxSceneRig.swift ─────────────────────────────────────────
// │ GELEN     : Design/BoxSceneBackground.swift → sahne kurulurken prepare(kit:), sonra her karede tick()
// │ GİDEN     : Design/CardboardBoxKit.swift (koli) | Design/DesignPalette.swift (spot ışığı rengi/gücü)
// │             onSettled kapanışı → Design/TapedBoxBackground.wrapScreen (bantlamayı başlatır)
// │             onFinished kapanışı → Design/BoxSceneBackground (kare aboneliğini kapatır)
// │ TEKNİK    : RealityKit fizik (PhysicsBodyComponent + CollisionComponent) + SpotLightComponent.
// │ REHBER    : Design/00_Rehber_Design.swift (hangi teknik nerede, okuma sırası)
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: kolileri sırayla sahneye bırakır, her karede hareketi ölçer, yığın durunca her şeyi dondurur.
// NEDEN class: kare aboneliği bir closure; struct kopyalanırdı, class aynı nesneyi paylaşır.
//
// ÖMÜR (koliler YALNIZ BİR KEZ düşer; bu bir oyun değil, arka plan):
//   1. prepare(kit:)      sahne kurulurken: birkaç KALIP koli üretilir (pahalı iş burada, bir kez) + ekran kartı ısıtılır
//   2. tick()             her karede: zamanı gelen koli kalıptan KOPYALANIP bırakılır (ucuz) → fizik motoru düşürür
//   3. onSettled          son koliden 1,7 sn sonra: bantlar başlar
//   4. freeze()           yığın gerçekten durunca: fizik kapatılır, kare aboneliği bırakılır
//   5. revealSpotlight()  en son: tepeden spot ışığı ORTADA küçük bir daire olarak yanar, dairesi giderek BÜYÜYÜP tüm kolileri kaplar
//   6. onStill            spot da bitince → StillScene sahneyi RESME çevirir, 3B motor kapanır (15 Kasım performans ⮕ Design/StillScene.swift)
//
// 15 Kasım KARARLARI (kullanıcı):
//   • Dağınık, fizikle düşen görünüm KALIR (sıralı/ızgara ve fiziksiz yığın denendi, beğenilmedi).
//   • Rastgelelik SABİT TOHUMLU (SeededRandom): her açılışta aynı koliler, aynı noktalardan, aynı sırayla bırakılır.
//     (Fizik kare sürelerine duyarlı olduğu için sonuç her seferinde milimetrik farklı olabilir; göz farkı görmez.)
//   • SON KOLİLER TEPEYE ÇIKMASIN: her koli, yığının o an EN ALÇAK yerinin üstünden bırakılır (spawnBox › lowestSpot)
//     → son 3-4 koli kule yapmaz, aradaki boşluklara düşer; yığın ekranın üst kısmına (başlığa) kadar yükselmez.
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
//   DONDURMA      : yığın durunca fizik ve ölçüm biter → sahne duran bir resimdir (pil/işlemci boşa harcanmaz).
// ⮕ KULLANIM [SceneRig]: kullanır: SceneBackground › rig
@MainActor
final class SceneRig {
    static let halfWidth: Float = 1.75   // yığının yarı genişliği (m) ≈ ekranın yarısı
    static let halfDepth: Float = 0.75   // yığının yarı derinliği (m): dar tutulur ki koliler YUKARI yığılsın
    static let boxCount = 36             // toplam koli | 15 Kasım: 24 → 36 (kullanıcı: "ekranın neredeyse tamamını kaplasın") — değişince BoxFall.json yeniden kaydedilmeli
    static let templateCount = 8         // kalıp sayısı: 8 farklı ölçü/renk, 24 koliye dağılır (göz tekrarı fark etmez)
    static let spawnInterval: Float = 0.08 // iki koli arası bekleme (sn) → yağmur gibi | 15 Kasım: 0,11 → 0,08 (kullanıcı: "biraz daha hızlı")

    var root: Entity?
    var keyLight: Entity?         // sahnenin ana ışığı: spot yanınca kısılır (BoxSceneBackground verir)
    var palette: Palette?         // spot ışığının rengi ve gücü
    var onSettled: (() -> Void)?  // son koliden 1,7 sn sonra, 1 kez → bantlar
    var onFinished: (() -> Void)? // yığın tamamen durunca, 1 kez → kare aboneliği kapanır + görünen huzme (TapedBoxBackground)
    var onStill: (() -> Void)?    // spot da bitince, 1 kez → StillScene sahneyi resme çevirir
    var subscription: Cancellable? // kare aboneliği (BoxSceneBackground kurar, dondurmada kapanır)
    static let seed: UInt64 = 0x59_4B_4D // "YKM": değiştirirsen yığın değişir (ama yine her açılışta aynı olur)
    private var rng = SeededRandom(seed: seed) // ⮕ Design/SeededRandom.swift
    private var settledFired = false
    private var finished = false

    // Kalıp: sahneye EKLENMEYEN hazır koli + onun çarpışma şekli. Sahneye giren koliler bunların kopyasıdır.
    private var templates: [(box: ModelEntity, shape: ShapeResource)] = []
    private var boxes: [(box: Entity, last: SIMD3<Float>)] = [] // sahnedeki koli + bir önceki karedeki konumu (durdu mu ölçümü için)
    // (15 Kasım, kullanıcı: "ayna olayını kaldır") zemindeki ters kopya yansımalar SİLİNDİ → çizilen koli sayısı yarıya indi, her karedeki eşitleme işi kalktı
    private var time: Float = 0
    private var nextSpawn: Float = 0.35 // ilk koli ekran açıldıktan 0,35 sn sonra
    private var stillFrames = 0        // art arda kaç karedir hiçbir koli kıpırdamadı

    // ─── KAYIT / OYNATMA (15 Kasım, kullanıcı: "her seferinde aynı şekilde düşsün") ───
    // SORUN: fizik motoru aynı başlangıçla bile her açılışta biraz farklı sonuç verir (kare süreleri değişir, küçük fark çarpışmaları değiştirir).
    // ÇÖZÜM: düşüş BİR KEZ fizikle kaydedildi (saniyede 30 kare, her kolinin konum + dönüşü) → Design/BoxFall.json uygulamanın içinde.
    //   Her açılışta fizik ÇALIŞMAZ; kayıt oynatılır → düşüş HER SEFERİNDE birebir aynı + fizik hesabı yok (daha hafif).
    //   Yeniden kaydetmek için (koli sayısı/ölçüsü değişirse): simülatörde "-recordFall" ile başlat → Documents/BoxFall.json → Design/'a kopyala.
    //   Kayıt dosyası yoksa ya da bozuksa: canlı fizik çalışır (eski yol), uygulama yine açılır.
    struct FallRecording: Codable { // Codable [SWIFT]: JSON'a yazılıp okunabilen tür
        struct Track: Codable { var t: Int; var start: Int; var f: [[Float]] } // t: kalıp no | start: ilk görüldüğü kare | f: kareler [x,y,z,qx,qy,qz,qw]
        var fps: Float; var settle: Int; var end: Int; var boxes: [Track]
    }
    static let recordMode = ProcessInfo.processInfo.arguments.contains("-recordFall") // [SWIFT] uygulamanın başlatma argümanları
    private var replay: FallRecording?                // doluysa OYNATMA kipi
    private var replayBoxes: [Entity] = []
    private var tracks: [FallRecording.Track] = []    // KAYIT kipi: biriken kareler
    private var sample = 0                            // KAYIT kipi: kaçıncı kare
    private var settleSample = 0

    // BU FONKSİYON: kalıp kolileri üretir. Pahalı iş (şekil üretimi) burada, koliler düşmeye başlamadan ÖNCE yapılır.
    // await Task.yield() [SWIFT]: "sıramı bir anlığına bırakıyorum" → her kalıptan sonra ekran bir kare çizebilir, dokunuş işlenebilir.
    // ⮕ KULLANIM [prepare]: kullanır: SceneBackground › RealityView.make (1 kez)
    func prepare(kit: CardboardBoxKit) async {
        for _ in 0..<Self.templateCount {
            // Ölçü: gerçek koliler gibi kimi küp, kimi yassı, kimi uzun | SABİT TOHUM → her açılışta aynı 8 ölçü
            let size = SIMD3<Float>(.random(in: 0.55...0.95, using: &rng), .random(in: 0.40...0.75, using: &rng), .random(in: 0.50...0.80, using: &rng))
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

        // OYNATMA hazırlığı: kayıt uygulamanın içinden okunur, her iz için bir koli (gizli) kurulur
        guard !Self.recordMode,
              let url = Bundle.main.url(forResource: "BoxFall", withExtension: "json"), // [SWIFT] uygulama paketindeki dosya
              let data = try? Data(contentsOf: url),
              let recording = try? JSONDecoder().decode(FallRecording.self, from: data),
              recording.boxes.allSatisfy({ $0.t < templates.count && !$0.f.isEmpty }) else { return }
        replay = recording
        for track in recording.boxes {
            let box = templates[track.t].box.clone(recursive: true)
            box.isEnabled = false // sırası gelene kadar gizli
            root.addChild(box)
            replayBoxes.append(box)
        }
    }

    // ⮕ KULLANIM [tick]: kullanır: SceneBackground › SceneEvents.Update aboneliği (her kare)
    func tick(deltaTime: Float) {
        guard !finished else { return } // donduktan sonra yapılacak iş yok
        time += deltaTime
        if replay != nil { playBack(); return } // OYNATMA: fizik yok, kayıttaki kareler

        // SIRAYLA BIRAK: zamanı gelince bir koli daha ekle (toplam boxCount olana kadar).
        while boxes.count < Self.boxCount, time >= nextSpawn {
            spawnBox()
            nextSpawn += Self.spawnInterval
        }

        // DURDU MU (bantlar için): son koli bırakıldıktan 1,7 sn sonra yığın yerleşmiş sayılır → dinleyene 1 kez haber ver.
        // NEDEN sahne saatiyle: yavaş telefonda sahne de yavaş akar; duvar saatiyle beklesek bant erken gelirdi.
        if !settledFired, boxes.count == Self.boxCount, time >= nextSpawn + 1.3 { // 15 Kasım: 1,7 → 1,3 (düşüş kısaldı)
            settledFired = true
            settleSample = sample
            onSettled?()
        }

        // KAYIT kipi: saniyede 30 kez her kolinin konum + dönüşünü yaz
        if Self.recordMode {
            while time >= Float(sample) / 30 {
                for i in boxes.indices {
                    let t = boxes[i].box.transform
                    let v = [t.translation.x, t.translation.y, t.translation.z, t.rotation.imag.x, t.rotation.imag.y, t.rotation.imag.z, t.rotation.real]
                    tracks[i].f.append(v.map { ($0 * 10000).rounded() / 10000 }) // 4 basamak: dosya küçük kalsın
                }
                sample += 1
            }
        }

        // HAREKET ÖLÇÜMÜ: her kolinin bu karede gittiği yol = şimdiki konum − bir önceki karedeki konum (en çok oynayan koli esas alınır)
        var maxMove: Float = 0
        for i in boxes.indices {
            let now = boxes[i].box.position
            maxMove = max(maxMove, simd_distance(now, boxes[i].last)) // simd_distance [SWIFT]: iki nokta arası uzaklık
            boxes[i].last = now
        }

        // GERÇEKTEN DURDU MU (dondurma için): bütün koliler bırakıldıysa ve 45 kare (~0,75 sn) boyunca en çok oynayan koli bile
        // yarım milimetreden az gittiyse yığın durmuştur. Emniyet: son koliden 8 sn sonra ne olursa olsun dondur (titreyen bir koli sahneyi sonsuza dek açık tutmasın).
        guard boxes.count == Self.boxCount else { return }
        stillFrames = maxMove < 0.0005 ? stillFrames + 1 : 0
        if stillFrames >= 45 || time >= nextSpawn + 8 { freeze() }
    }

    // BU FONKSİYON: yığını olduğu yerde sabitler. Koliler bir daha hareket etmez; dokunuşla da zıplamaz (bilerek: giriş ekranı oyun değil).
    // Fizik bileşenleri SİLİNİR: motor artık bu kolileri hiç hesaplamaz. Koliler son konumlarında görüntü olarak kalır. Sonra spot yanar.
    // ⮕ KULLANIM [freeze]: kullanır: tick
    private func freeze() {
        finished = true
        for pair in boxes {
            pair.box.components.remove(PhysicsBodyComponent.self)
            pair.box.components.remove(CollisionComponent.self)
        }
        templates.removeAll() // kalıplara artık gerek yok
        if Self.recordMode { // KAYDI YAZ: Documents/BoxFall.json (simülatörden alınıp Design/'a konur)
            let recording = FallRecording(fps: 30, settle: settleSample, end: sample, boxes: tracks)
            if let data = try? JSONEncoder().encode(recording),
               let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                try? data.write(to: dir.appendingPathComponent("BoxFall.json"))
                print("BOXFALL_WRITTEN", dir.appendingPathComponent("BoxFall.json").path)
            }
        }
        subscription?.cancel(); subscription = nil // kare aboneliği biter: tick artık çağrılmaz
        onFinished?()
        Task { @MainActor in
            await revealSpotlight()
            onStill?() // her şey durdu → ⮕ StillScene: resim + 3B kapanır
        }
    }

    // BU FONKSİYON: her şey düştükten sonra tepeden spot ışığını açar. ORTADAN YAYILARAK (14 Kasım, kullanıcı isteği):
    //   ışık önce yığının ortasında küçük bir daire olarak yanar, dairesi 2 sn içinde giderek büyür ve tüm kolileri kaplar.
    //   NASIL: SpotLightComponent'in koni açısı (outerAngle) her adımda büyütülür: 3° → 30°.
    //   KESKİN KENAR: iç açı dış açıdan yalnız 3° küçük → dairenin kenarı bulanık değil, net çizgi (sahne ışığı gibi).
    //   YAVAŞLAYARAK: büyüme "ease-out" (1 - (1-k)³) → başta hızlı açılır, kenara yaklaşınca yavaşlar.
    //   Aynı anda ana ışık %40a kısılır → ışık dairesinin dışı loş kalır, dairenin içindeki koliler parlak ve canlı öne çıkar.
    //   NEDEN Task + bekleme (kare aboneliği değil): abonelik dondurmada kapandı; kısa bir geçiş için yeniden açmaya değmez.
    // ⮕ KULLANIM [revealSpotlight]: kullanır: freeze
    private func revealSpotlight() async {
        guard let root, let palette, palette.isDark else { return } // YALNIZ KOYU MOD (14 Kasım, kullanıcı kararı): gündüzde spot ve kısma yok
        let spot = Entity()
        var light = SpotLightComponent(color: palette.spotColor, intensity: 0,
                                       innerAngleInDegrees: 1, outerAngleInDegrees: 3, attenuationRadius: 30)
        spot.components.set(light)
        spot.look(at: [0, 1.2, 0], from: [0, 11, 3], relativeTo: nil) // tam tepeden, hafif önden, yığının ortasına
        root.addChild(spot)

        let keyStart = keyLight?.components[DirectionalLightComponent.self]
        do { // (15 Kasım: Task yerine doğrudan bekler → bitince çağıran sahneyi resme çevirir)
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

    // BU FONKSİYON: kayıttaki kareleri oynatır. Şimdiki zaman kayıt karesine çevrilir (zaman × 30); iki kare arası yumuşak geçiş:
    //   konum doğrusal karışım (mix), dönüş küresel karışım (simd_slerp) → telefon 60 ya da 120 karede de akıcı.
    //   Bantlar kayıttaki "yerleşti" anında, dondurma kaydın sonunda → sonra spot ve resme dönme (canlı fizikteki sırayla aynı).
    // ⮕ KULLANIM [playBack]: kullanır: tick (oynatma kipi)
    private func playBack() {
        guard let replay else { return }
        let s = time * replay.fps
        for (i, track) in replay.boxes.enumerated() where s >= Float(track.start) {
            let box = replayBoxes[i]
            box.isEnabled = true
            let x = s - Float(track.start)
            let k = min(Int(x), track.f.count - 1), k2 = min(k + 1, track.f.count - 1)
            let w = min(max(x - Float(k), 0), 1)
            let a = track.f[k], b = track.f[k2]
            let pos = simd_mix(SIMD3(a[0], a[1], a[2]), SIMD3(b[0], b[1], b[2]), SIMD3(repeating: w)) // [SWIFT] iki nokta arası karışım
            let rot = simd_slerp(simd_quatf(ix: a[3], iy: a[4], iz: a[5], r: a[6]), simd_quatf(ix: b[3], iy: b[4], iz: b[5], r: b[6]), w)
            box.transform = Transform(rotation: rot, translation: pos)
        }
        if !settledFired, s >= Float(replay.settle) { settledFired = true; onSettled?() }
        if s >= Float(replay.end) { freeze() }
    }

    // BU FONKSİYON: birkaç aday nokta dener, her birinin çevresindeki EN YÜKSEK kolinin tepesine bakar, en alçak adayı seçer.
    //   Yere inmiş koliler sayılır (y < 5 m); düşmekte olanlar sayılmaz. Çevre: adayın ±0,55 m yanı, ±0,5 m önü/arkası.
    //   Sonuç: koliler önce yerdeki boşluklara düşer; yığın yayvan ve dağınık kalır, son koliler kule yapmaz.
    // ⮕ KULLANIM [lowestSpot]: kullanır: spawnBox
    private func lowestSpot() -> (x: Float, z: Float) {
        var best: (x: Float, z: Float, h: Float)?
        for _ in 0..<6 {
            let x = Float.random(in: -Self.halfWidth + 0.5...Self.halfWidth - 0.5, using: &rng)
            let z = Float.random(in: -Self.halfDepth + 0.4...Self.halfDepth - 0.4, using: &rng)
            var h: Float = 0
            for pair in boxes where pair.box.position.y < 5 {
                let p = pair.box.position
                if abs(p.x - x) < 0.55, abs(p.z - z) < 0.5 { h = max(h, p.y + 0.35) }
            }
            if best == nil || h < best!.h { best = (x, z, h) }
        }
        return (best!.x, best!.z)
    }

    // ⮕ KULLANIM [spawnBox]: kullanır: tick
    private func spawnBox() {
        guard let root else { return }
        let templateIndex = Int.random(in: 0..<templates.count, using: &rng) // sabit tohumlu seçim
        let template = templates[templateIndex]
        if Self.recordMode { tracks.append(.init(t: templateIndex, start: sample, f: [])) }

        // KALIPTAN KOPYA: clone(recursive:) [SWIFT] koliyi çocuklarıyla (bant, kapak, etiket) kopyalar; şekil ve malzeme paylaşılır.
        let box = template.box.clone(recursive: true)

        // Başlangıç: yığının EN ALÇAK yerinin üstünde, eğik (15 Kasım: son koliler tepeye çıkıp kule yapmasın diye)
        let spot = lowestSpot()
        box.position = [spot.x, .random(in: 6.6...8.0, using: &rng), spot.z] // ekranın üst kenarının hemen üstü (15 Kasım: 7,5-9,5 → daha kısa düşüş)
        box.orientation = simd_quatf(angle: .random(in: 0...(.pi), using: &rng), axis: simd_normalize([.random(in: -1...1, using: &rng), 1, .random(in: -1...1, using: &rng)]))

        // FİZİK: iki bileşen yeter.
        box.components.set(CollisionComponent(shapes: [template.shape])) // "şeklim bu, çarpışırım" | şekil de kalıpla birlikte hazır
        var body = PhysicsBodyComponent(massProperties: .default,
                                        material: .generate(friction: 0.7, restitution: 0.12), // sürtünme yüksek, zıplama az → karton hissi
                                        mode: .dynamic) // dynamic = yerçekimi ve çarpışmayla hareket eder
        body.angularDamping = 0.5 // dönmeyi söndür → koliler topaç gibi dönmez, çabuk durulur
        body.linearDamping = 0.05
        box.components.set(body)
        // İLK HIZ (15 Kasım, kullanıcı: "daha hızlı düşsün ama doğal akışında"): yerçekimi aynı kalır, koli ekrana zaten düşmekte olan
        //   bir hızla (3,5 m/sn ≈ 60 cm yukarıdan bırakılmış gibi) girer → yavaş "süzülme" anı olmaz, hareket fizikle doğal kalır.
        box.components.set(PhysicsMotionComponent(linearVelocity: [0, -3.5, 0])) // [SWIFT] fizik gövdesinin başlangıç hızı
        root.addChild(box)

        boxes.append((box, box.position))
    }
}
