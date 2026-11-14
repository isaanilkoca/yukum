//
//  BoxSceneBackground.swift
//  Yukum
//
//  3B koli sahnesi: bir ekranın TAMAMININ arkasına konan arka plan.
//

import SwiftUI    // [SWIFT] ekran çizim kütüphanesi
import RealityKit // [SWIFT] Apple'ın 3B motoru: şekil üretir, ışıklar, fizik hesaplar, kamerayla çizer (iOS'un içinde, ek kütüphane yok)

// ┌─ BAĞLANTI HARİTASI: BoxSceneBackground.swift ─────────────────────────────────────────
// │ GELEN     : Design/TapedBoxBackground.swift (koli + bant birlikte) → Views/LoginView. İleride: RegisterView, CarrierRegisterView.
// │ GİDEN     : Design/BoxSceneRig.swift (kolileri düşürür) | Design/CardboardBoxKit.swift (koli üretimi) | Design/DesignPalette.swift (renkler)
// │ TEKNİK    : RealityKit (RealityView). Model dosyası YOK; koliler kodla üretilir.
// │ REHBER    : Design/00_Rehber_Design.swift (hangi teknik nerede, okuma sırası)
// └──────────────────────────────────────────────────────────────────────

// ZİNCİR (ekran açılınca):
//   RealityView.make (1 kez) → buildScene(): zemin + görünmez duvarlar + ışıklar + kamera
//   → CardboardBoxKit.prepared() dokular (bekletmeden) → SceneRig.prepare() kalıp koliler
//   → content.subscribe(SceneEvents.Update): HER KAREDE SceneRig.tick()
//       ilk ~3 sn : koliler tek tek yukarıdan bırakılır → FİZİK MOTORU düşürür, çarpıştırır, üst üste yığar
//       sonra     : yığın yerleşir → onSettled() 1 kez çağrılır (ekran bantları bunu bekler)
//       en son    : yığın tamamen durur → SceneRig fiziği kapatır, onFinished() aboneliği bırakır → sahne duran bir resimdir
//
// NEDEN fizik motoru: her kolinin düşüşünü elle hesaplamıyoruz. Koliye "ağırlığın var, çarpışırsın" diyoruz (iki bileşen),
//   yerçekimi/çarpışma/yığılma RealityKit'ten bedava gelir. Her açılışta yığın biraz farklı oluşur → canlı durur.
// NEDEN görünmez duvarlar: koliler ekranın dışına yuvarlanıp kaybolmasın, yığın ekran genişliğinde kalsın.
// NEDEN yansıma kopyası: gerçek ayna yansıması telefonu yorar; kolinin ters kopyasını yarı saydam zeminin altına koymak aynı görüntüyü ucuza verir.

// ⮕ KULLANIM [SceneBackground]: kullanır: TapedBoxBackground › body
struct SceneBackground: View { // SceneBackground [BİZİM] ad | View [SWIFT]: bu bir ekran parçası

    @Environment(\.colorScheme) private var colorScheme // [SWIFT] telefon açık modda mı koyu modda mı
    @State private var updateSubscription: EventSubscription? // [SWIFT] kare aboneliği; saklanmazsa abonelik ölür, animasyon durur
    @State private var rig = SceneRig() // [BİZİM] kolileri düşüren ve yansımaları eşitleyen nesne (aşağıda)
    var onSettled: () -> Void = {} // [BİZİM] koliler durunca 1 kez çağrılır (ekran bandı bunu bekler)
    var onSpot: () -> Void = {}    // [BİZİM] yığın tamamen durup 3B spot yanınca 1 kez → TapedBoxBackground görünen huzmeyi ve karartmayı açar

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)

        ZStack { // ZStack [SWIFT]: elemanları üst üste dizer (arkadan öne)
            LinearGradient(colors: [palette.skyTop, palette.skyBottom], startPoint: .top, endPoint: .bottom)

            // Işık haleleri: arkada bulanık renkli bulutlar (stüdyo arka ışığı). 3B değil, ucuz 2B katman.
            Ellipse().fill(palette.glowA).frame(width: 380, height: 320).blur(radius: 95).offset(x: -120, y: -40)
            Ellipse().fill(palette.glowB).frame(width: 360, height: 300).blur(radius: 95).offset(x: 130, y: 120)

            RealityView { content in // RealityView [SWIFT]: SwiftUI içinde 3B sahne | bu blok 1 kez çalışır | blok async: içinde await kullanılabilir
                content.camera = .virtual // [SWIFT] AR değil: telefon kamerası açılmaz, sanal kamera kullanılır
                buildScene(in: &content, palette: palette) // zemin, duvarlar, ışıklar, kamera: hafif, hemen

                // AĞIR HAZIRLIK, BEKLETMEDEN (13 Kasım performans düzeltmesi): dokular ve kalıp koliler await ile üretilir.
                // Bu satırlarda sahne kurulumu durur ama EKRAN durmaz: giriş formu çizilmiş ve dokunulabilir kalır, koliler hazır olunca düşmeye başlar.
                PerfLog.reset("Giriş sahnesi kuruluyor")                   // GEÇİCİ ölçüm ⮕ App/PerfLog.swift (filtre: ⏱)
                let kit = await CardboardBoxKit.prepared(palette: palette) // ⮕ Design/CardboardBoxKit.swift (dokular)
                PerfLog.mark("giriş sahnesi: koli dokuları hazır")
                await rig.prepare(kit: kit)                                // ⮕ Design/BoxSceneRig.swift (kalıp koliler + ekran kartı ısınması) | 14 Kasım: yalnız koli
                PerfLog.mark("giriş sahnesi: kalıplar hazır, düşüş başlıyor")
                rig.palette = palette                                      // en sondaki spot ışığının rengi/gücü için

                rig.onSettled = onSettled
                // Yığın durunca kare aboneliğini bırak: tick artık çağrılmaz, sahne duran bir resim olarak kalır (pil ve işlemci boşa harcanmaz)
                rig.onFinished = {
                    updateSubscription?.cancel() // .cancel [SWIFT]: aboneliği sonlandırır
                    updateSubscription = nil
                    // Görünen huzme + karartma: 3B spot ışığıyla AYNI ANDA açılır | ⮕ TapedBoxBackground (SpotBeam bantların üstünde çizilir)
                    onSpot()
                }
                updateSubscription = content.subscribe(to: SceneEvents.Update.self) { event in // [SWIFT] her karede haber ver
                    rig.tick(deltaTime: Float(event.deltaTime))
                }
            }
        }
        .ignoresSafeArea() // çentik ve alt çubuk dahil tüm ekranı kapla
        // Arka plan dokunuşa CEVAP VERMEZ: koliler bir kez düşer ve kalır (oyun değil). Dokunuşlar doğrudan üstteki forma gider.
        .allowsHitTesting(false) // [SWIFT] bu görünüm dokunuş almasın
    }

    // ⮕ KULLANIM [buildScene]: kullanır: body › RealityView.make (1 kez)
    private func buildScene(in content: inout RealityViewCameraContent, palette: Palette) {
        let root = Entity() // [SWIFT] Entity: sahnedeki her şeyin ortak atası
        content.add(root)

        // 1) ZEMİN (görünen): koyu, yarı saydam levha. Saydamlık sayesinde altındaki ters koli kopyaları "yansıma" gibi görünür.
        var floorMaterial = PhysicallyBasedMaterial() // [SWIFT] fizik tabanlı malzeme: ışığa gerçek yüzey gibi tepki verir
        floorMaterial.baseColor = .init(tint: palette.floor)
        floorMaterial.roughness = 1.0
        floorMaterial.specular = .init(floatLiteral: 0.0) // zemin kendi parlamasın; "parlaklık" hissi yansıma kopyalarından gelir
        floorMaterial.blending = .transparent(opacity: .init(floatLiteral: palette.floorOpacity))
        let floor = ModelEntity(mesh: .generateBox(width: 60, height: 0.02, depth: 60), materials: [floorMaterial])
        floor.position.y = -0.01
        root.addChild(floor)

        // 2) ÇARPIŞMA SINIRLARI (görünmez): zemin + sol/sağ/ön/arka duvar. Yalnız fizik için; çizilmezler.
        //    mode: .static → yerinden oynamaz, ama düşen koliler buna çarpar.
        let walls: [(size: SIMD3<Float>, position: SIMD3<Float>)] = [
            ([20, 1, 20], [0, -0.5, 0]),                                   // zemin (üst yüzü y = 0)
            ([1, 30, 6], [-SceneRig.halfWidth - 0.5, 15, 0]),              // sol duvar
            ([1, 30, 6], [SceneRig.halfWidth + 0.5, 15, 0]),               // sağ duvar
            ([20, 30, 1], [0, 15, -SceneRig.halfDepth - 0.5]),             // arka duvar
            ([20, 30, 1], [0, 15, SceneRig.halfDepth + 0.5])               // ön duvar (koliler kameraya doğru dökülmesin)
        ]
        for wall in walls {
            let entity = Entity()
            entity.position = wall.position
            entity.components.set(CollisionComponent(shapes: [.generateBox(size: wall.size)])) // [SWIFT] çarpışma şekli
            entity.components.set(PhysicsBodyComponent(massProperties: .default,
                                                       material: .generate(friction: 0.8, restitution: 0.05),
                                                       mode: .static)) // [SWIFT] fizik gövdesi: static = sabit engel
            root.addChild(entity)
        }

        // 3) IŞIKLAR. Kural: önden SICAK beyaz (renkler doğru çıksın), arkadan/yandan DOYGUN renkli (kenarlar parlasın).
        let key = Entity()
        key.components.set(DirectionalLightComponent(color: palette.keyLight, intensity: palette.keyIntensity))
        key.components.set(DirectionalLightComponent.Shadow(maximumDistance: 30, depthBias: 2)) // [SWIFT] koliler birbirine gölge düşürür
        key.look(at: [0, 1.5, 0], from: [3, 9, 8], relativeTo: nil)
        root.addChild(key)

        let rims: [(from: SIMD3<Float>, color: UIColor)] = [
            ([-6, 5, -3], palette.rimA), // sol-arka
            ([6, 6, -3], palette.rimB),  // sağ-arka
            ([-6, 1.5, 5], palette.rimB) // sol-ön alçak: ön yüzlere ikinci renk
        ]
        for rimSpec in rims {
            let rim = Entity()
            rim.components.set(SpotLightComponent(color: rimSpec.color, intensity: palette.rimIntensity,
                                                  innerAngleInDegrees: 50, outerAngleInDegrees: 80, attenuationRadius: 30))
            rim.look(at: [0, 1.5, 0], from: rimSpec.from, relativeTo: nil)
            root.addChild(rim)
        }

        // 4) KAMERA: tam karşıdan, hafif yukarıdan. Sabit durur (koliler durunca sahne tamamen sakinleşsin).
        let camera = PerspectiveCamera() // [SWIFT] sanal kamera
        camera.camera.fieldOfViewInDegrees = 40
        camera.look(at: [0, 2.9, 0], from: [0, 3.6, 10.5], relativeTo: nil)
        root.addChild(camera)

        // 5) YANSIMA ATASI: y ekseninde ters çevrilmiş boş kutu. İçine konan her kopya zeminin altında baş aşağı görünür.
        let mirrorRoot = Entity()
        mirrorRoot.scale = [1, -1, 1]
        root.addChild(mirrorRoot)

        rig.root = root
        rig.mirrorRoot = mirrorRoot
        rig.keyLight = key // spot yanınca bu ışık kısılır (BoxSceneRig › revealSpotlight)
    }
}
