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
// │ TEKNİK    : RealityKit (StillScene içinde ARView, fizik motoru). Model dosyası YOK; koliler kodla üretilir. Bitince resme döner.
// │ REHBER    : Design/00_Rehber_Design.swift (hangi teknik nerede, okuma sırası)
// └──────────────────────────────────────────────────────────────────────

// ZİNCİR (ekran açılınca):
//   StillScene (1 kez) → buildScene(): zemin + görünmez duvarlar + ışıklar + kamera
//   → CardboardBoxKit.prepared() dokular (bekletmeden) → SceneRig.prepare() kalıp koliler
//   → scene.subscribe(SceneEvents.Update): HER KAREDE SceneRig.tick()
//       ilk ~3 sn : koliler tek tek yukarıdan bırakılır → FİZİK MOTORU düşürür, çarpıştırır, üst üste yığar
//       sonra     : yığın yerleşir → onSettled() 1 kez çağrılır (ekran bantları bunu bekler)
//       en son    : yığın tamamen durur → SceneRig fiziği kapatır, aboneliği bırakır → spot yanar → onStill → StillScene sahneyi RESME çevirir
//
// NEDEN fizik motoru: her kolinin düşüşünü elle hesaplamıyoruz. Koliye "ağırlığın var, çarpışırsın" diyoruz (iki bileşen),
//   yerçekimi/çarpışma/yığılma RealityKit'ten bedava gelir. Bırakma noktaları sabit tohumlu (her açılışta aynı) ve hep yığının en alçak yerinin üstünden (15 Kasım).
// NEDEN görünmez duvarlar: koliler ekranın dışına yuvarlanıp kaybolmasın, yığın ekran genişliğinde kalsın.
// (15 Kasım) Zemindeki ayna yansıması KALDIRILDI (kullanıcı kararı, performans): her koli için ikinci bir kopya çiziliyordu.

// ⮕ KULLANIM [SceneBackground]: kullanır: TapedBoxBackground › body
struct SceneBackground: View { // SceneBackground [BİZİM] ad | View [SWIFT]: bu bir ekran parçası

    @Environment(\.colorScheme) private var colorScheme // [SWIFT] telefon açık modda mı koyu modda mı
    @State private var rig = SceneRig() // [BİZİM] kolileri düşüren ve yığın durunca donduran nesne (aşağıda)
    var onSettled: () -> Void = {} // [BİZİM] koliler durunca 1 kez çağrılır (ekran bandı bunu bekler)
    var onSpot: () -> Void = {}    // [BİZİM] yığın tamamen durup 3B spot yanınca 1 kez → TapedBoxBackground görünen huzmeyi ve karartmayı açar

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)

        ZStack { // ZStack [SWIFT]: elemanları üst üste dizer (arkadan öne)
            LinearGradient(colors: [palette.skyTop, palette.skyBottom], startPoint: .top, endPoint: .bottom)

            // Işık haleleri: arkada bulanık renkli bulutlar (stüdyo arka ışığı). 3B değil, ucuz 2B katman.
            SoftGlow(color: palette.glowA, width: 380, height: 320).offset(x: -120, y: -40)
            SoftGlow(color: palette.glowB, width: 360, height: 300).offset(x: 130, y: 120)

            // 3B sahne | StillScene (15 Kasım performans): bir kez oynar, her şey durunca RESME döner, 3B motor kapanır ⮕ Design/StillScene.swift
            StillScene { root, scene, finish in
                buildScene(root: root, palette: palette) // zemin, görünmez duvarlar, ışıklar, kamera: hafif, hemen
                rig.palette = palette
                rig.onSettled = onSettled
                rig.onFinished = onSpot // görünen huzme + karartma: 3B spotla AYNI ANDA | ⮕ TapedBoxBackground
                rig.onStill = finish
                // AĞIR HAZIRLIK, BEKLETMEDEN: dokular (önbellekli) ve kalıp koliler await ile üretilir; form bu sırada dokunulabilir
                Task { @MainActor in
                    let kit = await CardboardBoxKit.prepared(palette: palette) // ⮕ Design/CardboardBoxKit.swift
                    await rig.prepare(kit: kit)                                // ⮕ Design/BoxSceneRig.swift
                    // HER KAREDE tick: koliler bırakılır, hareket ölçülür, durunca dondurulur (abonelik orada kapanır)
                    rig.subscription = scene.subscribe(to: SceneEvents.Update.self) { event in // [SWIFT] her karede haber ver
                        rig.tick(deltaTime: Float(event.deltaTime))
                    }
                }
            }
        }
        .ignoresSafeArea() // çentik ve alt çubuk dahil tüm ekranı kapla
        // Arka plan dokunuşa CEVAP VERMEZ: koliler bir kez düşer ve kalır (oyun değil). Dokunuşlar doğrudan üstteki forma gider.
        .allowsHitTesting(false) // [SWIFT] bu görünüm dokunuş almasın
    }

    // ⮕ KULLANIM [buildScene]: kullanır: body › StillScene (1 kez)
    private func buildScene(root: Entity, palette: Palette) {

        // 1) ZEMİN (görünen): koyu, OPAK levha (15 Kasım: yansımalar kaldırıldı → saydamlığa gerek yok; opak yüzey saydamdan ucuza çizilir)
        var floorMaterial = PhysicallyBasedMaterial() // [SWIFT] fizik tabanlı malzeme: ışığa gerçek yüzey gibi tepki verir
        floorMaterial.baseColor = .init(tint: palette.floor)
        floorMaterial.roughness = 1.0
        floorMaterial.specular = .init(floatLiteral: 0.0) // zemin kendi parlamasın
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

        rig.root = root
        rig.keyLight = key // spot yanınca bu ışık kısılır (BoxSceneRig › revealSpotlight)
    }
}
