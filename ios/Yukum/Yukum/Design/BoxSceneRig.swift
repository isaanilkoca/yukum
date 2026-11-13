//
//  BoxSceneRig.swift
//  Yukum
//
//  Kolileri sırayla düşüren, yansımalarını eşitleyen, yığın durunca sahneyi donduran nesne.
//

import RealityKit // [SWIFT] Apple'ın 3B motoru: şekil üretir, ışıklar, fizik hesaplar, kamerayla çizer (iOS'un içinde, ek kütüphane yok)
import UIKit      // [SWIFT] UIColor, UIImage ve resim çizici (UIGraphicsImageRenderer) buradan gelir

// ┌─ BAĞLANTI HARİTASI: BoxSceneRig.swift ─────────────────────────────────────────
// │ GELEN     : Design/BoxSceneBackground.swift → sahne kurulurken prepare(kit:), sonra her karede tick()
// │ GİDEN     : onSettled kapanışı → Design/TapedBoxBackground.wrapScreen (bantlamayı başlatır)
// │             onFinished kapanışı → Design/BoxSceneBackground (kare aboneliğini kapatır)
// │ TEKNİK    : RealityKit fizik (PhysicsBodyComponent + CollisionComponent).
// │ REHBER    : Design/00_Rehber_Design.swift (hangi teknik nerede, okuma sırası)
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: kolileri sırayla sahneye bırakır, her karede yansıma kopyalarını asıllarıyla eşitler, yığın durunca her şeyi dondurur.
// NEDEN class: kare aboneliği bir closure; struct kopyalanırdı, class aynı nesneyi paylaşır.
//
// ÖMÜR (koliler YALNIZ BİR KEZ düşer; bu bir oyun değil, arka plan):
//   1. prepare(kit:)  sahne kurulurken: birkaç KALIP koli üretilir (pahalı iş burada, bir kez)
//   2. tick()         her karede: zamanı gelen koli kalıptan KOPYALANIP bırakılır (ucuz) → fizik motoru düşürür
//   3. onSettled      son koliden 1,7 sn sonra: bantlar başlar
//   4. freeze()       yığın gerçekten durunca: fizik kapatılır, kare aboneliği bırakılır → sahne artık yalnız duran bir resimdir
//
// PERFORMANS NOTLARI (13 Kasım, gerçek cihazda takılma görülünce):
//   KALIP + KOPYA : eskiden her koli bırakılırken şekli (köşesi yuvarlak kutu + bant + kapak + etiket) sıfırdan üretiliyordu.
//                   Ölçüm: 24 koliyi üretmek ≈ 190 ms, 24 koliyi KOPYALAMAK ≈ 2 ms (simülatörde). Şekil üretimi koli düşerken
//                   kare aralarına sığmıyor, düşüş takılıyordu. Şimdi 8 kalıp önceden üretilir; düşen her koli bir kalıbın kopyasıdır.
//                   Kopya, şekil ve malzemeyi PAYLAŞIR (yeniden üretmez) → hem hızlı hem bellekte az yer.
//   DONDURMA      : eskiden yığın durduktan sonra da fizik motoru her karede 24 koliyi hesaplıyor, biz de 24 yansımayı eşitliyorduk
//                   (kullanıcı giriş ekranında kaldığı sürece, boşuna). Şimdi yığın durunca ikisi de biter.
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

    // BU FONKSİYON: kalıp kolileri üretir. Pahalı iş (şekil üretimi) burada, koliler düşmeye başlamadan ÖNCE yapılır.
    // await Task.yield() [SWIFT]: "sıramı bir anlığına bırakıyorum" → her kalıptan sonra ekran bir kare çizebilir, dokunuş işlenebilir.
    //   Yield olmasa 8 kalıp tek parça hâlinde üretilir, o süre boyunca ekran donardı.
    // ⮕ KULLANIM [prepare]: kullanır: SceneBackground › RealityView.make (1 kez)
    func prepare(kit: CardboardBoxKit) async {
        for _ in 0..<Self.templateCount {
            // Rastgele ölçü: gerçek koliler gibi kimi küp, kimi yassı, kimi uzun.
            let size = SIMD3<Float>(.random(in: 0.55...0.95), .random(in: 0.40...0.75), .random(in: 0.50...0.80))
            templates.append((kit.makeBox(size: size), .generateBox(size: size))) // bantlı, etiketli hazır koli: Design/CardboardBoxKit.swift
            await Task.yield()
        }
    }

    // ⮕ KULLANIM [tick]: kullanır: SceneBackground › SceneEvents.Update aboneliği (her kare)
    func tick(deltaTime: Float) {
        guard !finished else { return } // donduktan sonra yapılacak iş yok
        time += deltaTime

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
    // Fizik bileşenleri SİLİNİR: motor artık bu kolileri hiç hesaplamaz. Koliler son konumlarında görüntü olarak kalır.
    // ⮕ KULLANIM [freeze]: kullanır: tick
    private func freeze() {
        finished = true
        for pair in pairs {
            pair.box.components.remove(PhysicsBodyComponent.self)
            pair.box.components.remove(CollisionComponent.self)
        }
        templates.removeAll() // kalıplara artık gerek yok
        onFinished?()
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
