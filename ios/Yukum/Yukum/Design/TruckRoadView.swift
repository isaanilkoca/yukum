//
//  TruckRoadView.swift
//  Yukum
//
//  Yük teslim alma sahnesi: dorse yoldan geri geri yükleme alanına yanaşır, durur; yanında bekleyen yük yığını
//  arka kapıdan tek tek içeri alınır. BİR KEZ oynar, sonra her şey durur.
//  Taşımacı ana ekranının arka planı (14 Kasım).
//

import SwiftUI    // [SWIFT] ekran çizim kütüphanesi
import RealityKit // [SWIFT] Apple'ın 3B motoru
import UIKit      // [SWIFT] UIColor (3B malzeme ve ışıklar bunu ister)

// ┌─ BAĞLANTI HARİTASI: TruckRoadView.swift ─────────────────────────────────────────
// │ GELEN     : Views/HomeView.swift › carrierBackground (Taşımacı ana ekranı, tam ekran arka plan)
// │ GİDEN     : Design/StillScene.swift (bitince resme döner) | Design/TruckLoadView.swift › TruckModel (aynı Truck.usdz, giriş ekranında önceden yüklenir; ikinci kez yüklenmez)
// │             Design/CardboardBoxKit.swift (koliler) | Design/CargoKit.swift (meyve kasası, zeytinyağı, çuval) | Design/DesignPalette.swift
// │ TEKNİK    : 2B (SwiftUI Canvas): gökyüzü, yıldızlar, ufuk ışığı, sıradağlar, arazi (hepsi DURAĞAN)
// │             3B (RealityKit): yol, yükleme alanı, paletler, dorse, yükler, ışıklar
// │ REHBER    : Design/00_Rehber_Design.swift
// └──────────────────────────────────────────────────────────────────────
//
// ZİNCİR (tek seferlik, toplam ~8 sn):
//   make → ışık, kamera → model hazır → prepareTrailer (kabin çıkar, arka kapı sağa) → buildGround (yol + yükleme alanı)
//   → buildCargo: 42 yük, yükleme alanında paletlerin üstünde YIĞIN olarak durur
//   → play: 1) YANAŞMA: dorse soldan, arka kapısı önde, yavaşlayarak geri geri gelir, yığının dibinde durur (2,8 sn)
//           2) YÜKLEME: her yük yığından kalkar → kapının önüne gelir → kasaya kayarak yerine oturur (önce en dip, sonra kapıya doğru)
//           3) DURUR: yığın boşalır, dorse dolu kalır. Sonra hiçbir şey hareket etmez
//              (kullanıcı kararı 14 Kasım: "sürekli hareket olmasın; gelsin, olsun, dursun" → ilk sürümdeki akan yol kaldırıldı).
//
// NEDEN Yük Veren'den farklı: Yük Veren'de yükler yukarıdan kasaya iner (yükünü hazırlıyor).
//   Taşımacı'da dorse YOLDAN gelir ve yük YERDEN alınır → "yükü teslim almaya geldim". Dorse aynı model, kasa yine şeffaf (içi görünsün).
// NEDEN fizik yok: yükün yolu düzgün olmalı (forklift gibi); rastgele sekme "kaza" gibi görünür. Tüm hareket move(to:) ile.

// ⮕ KULLANIM [TruckRoadView]: kullanır: HomeView › carrierBackground
struct TruckRoadView: View { // TruckRoadView [BİZİM] ad | View [SWIFT]: bu bir ekran parçası
    @Environment(\.colorScheme) private var colorScheme // [SWIFT] açık/koyu mod → palet
    @State private var rig = TruckRoadRig() // [BİZİM] sahneyi tutan nesne | @State: ekran yenilense de aynı sahne kalır (animasyon yeniden oynamaz)

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        ZStack {
            // 1) 2B ARKA PLAN (durağan) | Canvas [SWIFT]: tek bir yüzeye kodla çizer
            Canvas { ctx, size in
                let horizon = TruckRoadRig.horizonY(in: size) // ufuk çizgisi KAMERADAN hesaplanır → 3B yol tam dağların dibinde kaybolur
                let w = size.width

                // gökyüzü: üst renkten ufuk rengine
                ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: horizon + 1)),
                         with: .linearGradient(Gradient(colors: [palette.skyTop, palette.skyBottom]), startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))

                // yıldızlar (yalnız gece) | sabit liste → her açılışta aynı gökyüzü
                if palette.isDark {
                    for s in Self.stars {
                        ctx.fill(Path(ellipseIn: CGRect(x: s.x * w, y: s.y * horizon * 0.8, width: s.r, height: s.r)), with: .color(palette.star.opacity(s.a)))
                    }
                }

                // ufuk ışığı: yolun ufka gittiği taraf (sol) | gündüz güneş, gece uzaktaki şehir
                ctx.drawLayer { layer in // drawLayer [SWIFT]: bulanıklık yalnız bu katmana uygulansın
                    layer.addFilter(.blur(radius: 46))
                    layer.fill(Path(ellipseIn: CGRect(x: w * 0.30 - 210, y: horizon - 95, width: 420, height: 170)), with: .color(palette.horizonGlow))
                }

                // sıradağlar: uzak (açık) + yakın (koyu) → derinlik | yükseklikler ekran enine göre ölçeklenir
                let k = w / 390
                ctx.fill(Self.ridge(width: w, base: horizon + 1, heights: [14, 30, 20, 44, 26, 52, 24, 38, 18, 42, 26, 14].map { $0 * k }), with: .color(palette.hillFar))
                ctx.fill(Self.ridge(width: w, base: horizon + 1, heights: [6, 16, 9, 22, 8, 14, 26, 11, 18, 7, 12].map { $0 * k }), with: .color(palette.hillNear))

                // arazi: ufukta puslu (açık), aşağıya doğru koyulaşır
                ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: size.height - horizon)),
                         with: .linearGradient(Gradient(colors: [palette.landHaze, palette.land]),
                                               startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: horizon + (size.height - horizon) * 0.45)))
            }

            // 2) 3B SAHNE: zemini saydam → arkadaki Canvas görünür | StillScene: bir kez oynar, bitince resme döner, 3B motor kapanır (PERFORMANS ⮕ Design/StillScene.swift)
            StillScene { root, _, finish in
                rig.build(root: root, palette: palette, finish: finish)
            }
        }
    }

    // Sıradağ çizgisi: eşit aralıklı tepe noktaları, alt kenarı ufukta kapalı şekil (alçak poligon görünüm, CargoKit ile aynı dil)
    // ⮕ KULLANIM [ridge]: kullanır: body › Canvas
    private static func ridge(width: CGFloat, base: CGFloat, heights: [CGFloat]) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: base))
        for (i, height) in heights.enumerated() {
            path.addLine(to: CGPoint(x: width * CGFloat(i) / CGFloat(heights.count - 1), y: base - height))
        }
        path.addLine(to: CGPoint(x: width, y: base))
        path.closeSubpath()
        return path
    }

    // Yıldızlar: (x, y) ekranın 0…1 oranı, r çap, a parlaklık | sabit sayı üreteci (LCG) → rastgele görünür ama hep aynı
    private static let stars: [(x: CGFloat, y: CGFloat, r: CGFloat, a: Double)] = {
        var seed: UInt32 = 7
        func next() -> CGFloat { seed = seed &* 1_664_525 &+ 1_013_904_223; return CGFloat(seed >> 8) / CGFloat(1 << 24) } // &* &+ [SWIFT]: taşmaya izin veren çarpma/toplama
        return (0..<34).map { _ in (next(), next(), 1 + next() * 1.6, 0.25 + Double(next()) * 0.55) }
    }()
}

// BU SINIF: 3B sahneyi kurar ve TEK SEFERLİK yanaşma + yükleme koreografisini oynatır.
// KOORDİNAT: yol X ekseni boyunca (solda ufka gider), dorsenin arka kapısı +X'e (sağa) bakar, yükleme alanı kapının arkasında.
//   Dorsenin DURDUĞU yer sahnenin merkezi (0, 0, 0) → yüklerin kasadaki yerleri doğrudan sahne koordinatında hesaplanır.
// ⮕ KULLANIM [TruckRoadRig]: kullanır: TruckRoadView › rig, body › Canvas (horizonY)
@MainActor
final class TruckRoadRig {
    // ── OYNANACAK SAYILAR ──
    static let trailerLength: Float = 8.0              // dorse boyu (Yük Veren ile aynı)
    static let grid = (length: 7, height: 3, width: 2) // kasadaki düzen: 42 hücre (Yük Veren ile aynı)
    static let stackGrid = (x: 3, z: 5, y: 3)          // yerdeki yığın: 3 × 5 palet, 3 kat (45 yer, 42'si dolu)
    static let arriveFrom: Float = -20                 // dorse bu kadar soldan gelir (m)
    static let arriveSeconds: Double = 2.8             // yanaşma süresi
    static let loadInterval: Double = 0.11             // iki yükün yığından kalkışı arası (42 × 0,11 ≈ 4,6 sn)
    static let roadCenterZ: Float = -1.8               // dorse yakın şeritte (z = 0), yolun ortası biraz geride
    static let roadHalfWidth: Float = 4.0

    // KAMERA: sol-önden, yukarıdan → dorsenin uzun yanı, arka kapısı ve sağdaki yükleme alanı birlikte görünür; yol solda ufka uzanır
    // NEDEN nonisolated [SWIFT]: proje varsayılanı MainActor; Canvas çizimi ondan bağımsız çalışır → sabitler her yerden okunabilsin (değişmedikleri için güvenli)
    nonisolated static let cameraFrom: SIMD3<Float> = [-3.5, 4.6, 12.5]
    nonisolated static let cameraAt: SIMD3<Float> = [2.3, 1.1, 0]
    nonisolated static let fieldOfView: Float = 60 // derece, ekranın ENİNE göre (her telefonda yatayda aynı görüntü)

    // BU FONKSİYON: kameranın ufuk çizgisinin ekrandaki yüksekliği.
    // NASIL: bakış yönünün yatay hali kameranın eksenlerine izdüşürülür: (yukarı / ileri) oranı × odak uzaklığı (f = (en / 2) / tan(görüş açısı / 2)).
    //   Kamera yatık değil (look(at:) yukarıyı Y tutar) → bütün yatay yönler aynı yükseklikte = ufuk düz bir çizgi.
    // ⮕ KULLANIM [horizonY]: kullanır: TruckRoadView › body › Canvas
    nonisolated static func horizonY(in size: CGSize) -> CGFloat {
        let forward = simd_normalize(cameraAt - cameraFrom)
        let right = simd_normalize(simd_cross(forward, [0, 1, 0]))
        let up = simd_cross(right, forward)
        let level = simd_normalize(SIMD3<Float>(forward.x, 0, forward.z))
        let f = Float(size.width / 2) / tan(fieldOfView * .pi / 360)
        return size.height / 2 - CGFloat(f * simd_dot(level, up) / simd_dot(level, forward))
    }

    private var played = false              // koreografi bir kez oynar
    private var cellSize: SIMD3<Float> = [1, 0.8, 1] // kasadaki bir hücrenin ölçüsü (yerdeki yığın da bu ölçüyle dizilir)

    private var remaining = 0 // henüz yerine oturmamış yük sayısı
    private var finish: (@MainActor () -> Void)? // yükleme bitince StillScene'e "dur" der (sahne resme döner)

    // ⮕ KULLANIM [build]: kullanır: TruckRoadView › StillScene (1 kez)
    func build(root: Entity, palette: Palette, finish: @escaping @MainActor () -> Void) {
        self.finish = finish

        // 1) IŞIKLAR: Yük Veren dorse sahnesiyle aynı dil (önden güçlü sıcak beyaz + dolgu + iki renkli kenar ışığı)
        let key = Entity()
        key.components.set(DirectionalLightComponent(color: palette.keyLight, intensity: palette.trailerKeyIntensity))
        key.components.set(DirectionalLightComponent.Shadow(maximumDistance: 40, depthBias: 2))
        key.look(at: [2, 1, 0], from: [-5, 10, 9], relativeTo: nil)
        root.addChild(key)
        let fill = Entity()
        fill.components.set(DirectionalLightComponent(color: palette.keyLight, intensity: palette.trailerFillIntensity))
        fill.look(at: [2, 1.5, 0], from: [9, 3, 10], relativeTo: nil)
        root.addChild(fill)
        for (from, color) in [(SIMD3<Float>(-8, 5, -6), palette.rimA), (SIMD3<Float>(10, 6, -6), palette.rimB)] {
            let rim = Entity()
            rim.components.set(SpotLightComponent(color: color, intensity: palette.rimIntensity,
                                                  innerAngleInDegrees: 50, outerAngleInDegrees: 80, attenuationRadius: 40))
            rim.look(at: [2, 2, 0], from: from, relativeTo: nil)
            root.addChild(rim)
        }

        // 2) KAMERA
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewOrientation = .horizontal
        camera.camera.fieldOfViewInDegrees = Self.fieldOfView
        camera.look(at: Self.cameraAt, from: Self.cameraFrom, relativeTo: nil)
        root.addChild(camera)

        // 3) MODEL → zemin → yükler → koreografi
        Task { @MainActor in
            guard let truck = await TruckModel.instance() else { return } // ⮕ TruckLoadView.swift › TruckModel (önceden yüklü)
            let holder = Entity() // dorseyi taşıyan kutu: yanaşma animasyonu YALNIZ bunun konumunu değiştirir
            guard let shell = self.prepareTrailer(truck, in: holder, palette: palette) else { return }

            // hücre ölçüsü kasanın gerçek iç hacminden (Yük Veren ile aynı hesap) → yığın ve yükleme alanı buna göre
            let inner = (shell.max - SIMD3<Float>(0.14, 0.30, 0.12)) - (shell.min + SIMD3<Float>(0.14, 0.10, 0.12))
            self.cellSize = inner / SIMD3<Float>(Float(Self.grid.length), Float(Self.grid.height), Float(Self.grid.width))

            self.buildGround(in: root, rearX: shell.max.x, palette: palette)
            let loads = await self.buildCargo(trailerShell: shell, root: root, palette: palette)

            holder.position = [Self.arriveFrom, 0, 0] // başlangıç: solda, yolun üstünde
            root.addChild(holder)
            self.play(holder: holder, loads: loads)
        }
    }

    // BU FONKSİYON: modeli dorseye çevirir (kabin çıkar), ölçekler, arka kapısı +X'e bakacak şekilde döndürür, kasayı şeffaflaştırır,
    //   kasa kenarlarına ışıklı çerçeve çizer. Kasanın (yanaşmış haldeki) kutusunu geri verir.
    // NASIL yön bulunur: kabin ("Truck_head...") silinmeden önce yerine görünmez bir İŞARET konur; ölçek/dönüşten sonra işaret hangi taraftaysa orası ÖN.
    // HİYERARŞİ: holder (yanaşma: yalnız konum) → pivot (yön: 0° ya da 180°) → truck (model: ölçek + ortalama)
    // ⮕ KULLANIM [prepareTrailer]: kullanır: build
    private func prepareTrailer(_ truck: Entity, in holder: Entity, palette: Palette) -> BoundingBox? {
        let pivot = Entity()
        holder.addChild(pivot)
        pivot.addChild(truck)

        let front = Entity() // görünmez işaret (şekli yok → ölçüye girmez)
        if let head = truck.findEntity(named: "Truck_head_Truck_head_L_1") {
            front.position = head.visualBounds(relativeTo: truck).center
        }
        truck.addChild(front)
        removeTractor(truck)

        // Ölçü: en uzun kenar 8 m, uzun eksen X'e, tekerler y = 0'a, ortası 0'a (Yük Veren ile aynı yol)
        let bounds = truck.visualBounds(relativeTo: holder)
        truck.scale *= SIMD3(repeating: Self.trailerLength / max(max(bounds.extents.x, bounds.extents.z), 0.001))
        if bounds.extents.z > bounds.extents.x {
            truck.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0]) * truck.orientation
        }
        let fitted = truck.visualBounds(relativeTo: holder)
        truck.position -= [fitted.center.x, fitted.min.y, fitted.center.z]

        // Ön +X'teyse 180° çevir → arka kapı +X'e (yükleme alanına) bakar
        if front.position(relativeTo: holder).x > 0 {
            pivot.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
        }

        guard let shellEntity = repaint(truck, palette: palette) else { return nil }
        let shell = shellEntity.visualBounds(relativeTo: holder)

        // Kasa çerçevesi: 12 kenara ince ışıklı çubuk | holder'ın çocuğu → yanaşırken dorseyle birlikte gelir
        let edge = UnlitMaterial(color: palette.cargoEdge) // [SWIFT] ışıktan etkilenmez → hep parlak
        let t: Float = 0.04, e = shell.extents, c = shell.center
        func bar(_ size: SIMD3<Float>, _ at: SIMD3<Float>) {
            let b = ModelEntity(mesh: .generateBox(size: size), materials: [edge]); b.position = at; holder.addChild(b)
        }
        for a: Float in [-1, 1] { for b: Float in [-1, 1] {
            bar([e.x, t, t], [c.x, c.y + a * e.y / 2, c.z + b * e.z / 2]) // boyuna
            bar([t, e.y, t], [c.x + a * e.x / 2, c.y, c.z + b * e.z / 2]) // dikey
            bar([t, t, e.z], [c.x + a * e.x / 2, c.y + b * e.y / 2, c.z]) // enine
        } }
        return shell // holder henüz (0,0,0)'da → bu kutu, yanaşmış dorsenin sahnedeki kutusu
    }

    // BU FONKSİYON: kabini ve kasa boyunun dışında kalan her şeyi (kabin tekerleri, egzoz...) çıkarır. Yük Veren'deki trailerOnly ile aynı kural.
    // ⮕ KULLANIM [removeTractor]: kullanır: prepareTrailer
    private func removeTractor(_ truck: Entity) {
        truck.findEntity(named: "Truck_head_Truck_head_L_1")?.removeFromParent()
        guard let body = truck.findEntity(named: "Truck_body_Truck_body_L_3") else { return }
        let shell = body.visualBounds(relativeTo: truck)
        let alongX = shell.extents.x > shell.extents.z
        let low = (alongX ? shell.min.x : shell.min.z) - 0.05, high = (alongX ? shell.max.x : shell.max.z) + 0.05
        var outside: [Entity] = []
        func visit(_ entity: Entity) {
            if entity === body { return }
            if entity.components.has(ModelComponent.self) {
                let center = entity.visualBounds(relativeTo: truck).center
                let along = alongX ? center.x : center.z
                if along < low || along > high { outside.append(entity); return }
            }
            for child in entity.children { visit(child) }
        }
        visit(truck)
        for entity in outside { entity.removeFromParent() } // gezerken değil, sonra sil
    }

    // BU FONKSİYON: kasayı şeffaf cam yapar (yükler içeride görünsün), camları füme, lambaları ışıklı. Kasa parçasını geri verir.
    // ⮕ KULLANIM [repaint]: kullanır: prepareTrailer
    private func repaint(_ entity: Entity, palette: Palette) -> Entity? {
        var cargoShell: Entity?
        if var model = entity.components[ModelComponent.self] {
            model.materials = model.materials.map { material in
                switch material.name { // malzeme adları modelden (usdcat Truck.usdz)
                case "bodycolour":
                    cargoShell = entity
                    var glass = PhysicallyBasedMaterial()
                    glass.baseColor = .init(tint: palette.cargoGlass)
                    glass.roughness = 0.05
                    glass.blending = .transparent(opacity: .init(floatLiteral: 0.07)) // %7 opak (Yük Veren ile aynı)
                    return glass
                case "glass", "windglass", "full_glass":
                    var glass = PhysicallyBasedMaterial()
                    glass.baseColor = .init(tint: UIColor(red: 0.02, green: 0.02, blue: 0.025, alpha: 1))
                    glass.roughness = 0.04
                    return glass
                case "signal_light", "signal_light_001":
                    var lamp = PhysicallyBasedMaterial()
                    lamp.baseColor = .init(tint: .white)
                    lamp.emissiveColor = .init(color: UIColor(red: 1.0, green: 0.92, blue: 0.75, alpha: 1))
                    lamp.emissiveIntensity = palette.isDark ? 6 : 1.5
                    return lamp
                default:
                    return material // lastik, jant, şasi: modeldeki haliyle
                }
            }
            entity.components.set(model)
        }
        for child in entity.children {
            if let found = repaint(child, palette: palette) { cargoShell = found }
        }
        return cargoShell
    }

    // BU FONKSİYON: zemin (hepsi DURAĞAN).
    //   YOL: dorsenin arka kapısında biter, solda ufka uzanır; 15 m'lik dilimler uzaklaştıkça saydamlaşır → 2B araziye karışır (keskin kenar kalmaz).
    //   YÜKLEME ALANI: kapının arkasında açık renk beton + yığının çevresinde turuncu sınır çizgisi + gece projektör.
    // ⮕ KULLANIM [buildGround]: kullanır: build
    private func buildGround(in root: Entity, rearX: Float, palette: Palette) {
        let yardStart = rearX + 0.5
        let segment: Float = 15, far: Float = -230, fadeStart: Float = -90

        var x = yardStart
        while x > far {
            let length = min(segment, x - far)
            let center = x - length / 2
            let fade = center > fadeStart ? 1 : max(0, 1 - (fadeStart - center) / (fadeStart - far)) // 1 opak, 0 görünmez
            var asphalt = PhysicallyBasedMaterial()
            asphalt.baseColor = .init(tint: palette.asphalt)
            asphalt.roughness = 0.92 // mat
            if fade < 1 { asphalt.blending = .transparent(opacity: .init(floatLiteral: fade)) }
            let road = ModelEntity(mesh: .generatePlane(width: length, depth: Self.roadHalfWidth * 2), materials: [asphalt]) // generatePlane [SWIFT]: yere yatık düzlem (en X, derinlik Z)
            road.position = [center, 0, Self.roadCenterZ]
            root.addChild(road)

            if center > -150 { // şerit çizgileri: kenarlar kesintisiz, orta kesik (4 m çizgi + 8 m boşluk)
                var line = UnlitMaterial(color: palette.roadLine) // [SWIFT] ışıktan etkilenmez: gece de okunur
                if fade < 1 { line.blending = .transparent(opacity: .init(floatLiteral: fade)) }
                for side: Float in [-1, 1] {
                    let edgeLine = ModelEntity(mesh: .generatePlane(width: length, depth: 0.16), materials: [line])
                    edgeLine.position = [center, 0.006, Self.roadCenterZ + side * (Self.roadHalfWidth - 0.3)] // 0,006 m: asfaltla titreşmesin
                    root.addChild(edgeLine)
                }
                var dash = x - 3
                while dash - 2 > x - length {
                    let piece = ModelEntity(mesh: .generatePlane(width: 4, depth: 0.15), materials: [line])
                    piece.position = [dash, 0.008, Self.roadCenterZ]
                    root.addChild(piece)
                    dash -= 12
                }
                // yol kenarı dikmeleri (her 20 m, yakın kenarda): beyaz direk + turuncu reflektör
                var post = x - 6
                while post > x - length {
                    let stick = ModelEntity(mesh: .generateBox(size: [0.12, 1.0, 0.12], cornerRadius: 0.02),
                                            materials: [SimpleMaterial(color: palette.postWhite, roughness: 0.6, isMetallic: false)])
                    let reflector = ModelEntity(mesh: .generateBox(size: [0.13, 0.14, 0.02]), materials: [UnlitMaterial(color: palette.reflector)])
                    reflector.position = [0, 0.33, 0.07] // kameraya bakan yüzde
                    stick.addChild(reflector)
                    stick.position = [post, 0.5, Self.roadCenterZ + Self.roadHalfWidth + 0.7]
                    root.addChild(stick)
                    post -= 20
                }
            }
            x -= length
        }

        // Yükleme alanı: beton zemin (yoldan 6 cm yüksek: kaldırım hissi)
        var concrete = PhysicallyBasedMaterial()
        concrete.baseColor = .init(tint: palette.concrete)
        concrete.roughness = 0.85
        let yard = ModelEntity(mesh: .generateBox(size: [9, 0.12, 9]), materials: [concrete])
        yard.position = [yardStart + 4.5, 0, 0] // yığın + çevresinde 1 m pay (ilk denemede 16 × 14 m: ekranın sağını kaplıyordu)
        root.addChild(yard)

        // Yığının çevresinde turuncu sınır (yükleme noktası işareti)
        let bay = UnlitMaterial(color: palette.reflector)
        let span = stackSpan(rearX: rearX)
        let midX = (span.min.x + span.max.x) / 2, midZ = (span.min.z + span.max.z) / 2
        let lenX = span.max.x - span.min.x + 0.6, lenZ = span.max.z - span.min.z + 0.6
        for (size, at) in [
            (SIMD3<Float>(lenX, 0.01, 0.12), SIMD3<Float>(midX, 0.065, span.min.z - 0.3)),
            (SIMD3<Float>(lenX, 0.01, 0.12), SIMD3<Float>(midX, 0.065, span.max.z + 0.3)),
            (SIMD3<Float>(0.12, 0.01, lenZ), SIMD3<Float>(span.min.x - 0.3, 0.065, midZ)),
            (SIMD3<Float>(0.12, 0.01, lenZ), SIMD3<Float>(span.max.x + 0.3, 0.065, midZ))
        ] {
            let line = ModelEntity(mesh: .generateBox(size: size), materials: [bay])
            line.position = at
            root.addChild(line)
        }

        // Gece: yükleme alanı projektörü (kapıyı ve yığını yukarıdan aydınlatır) | gündüz kurulmaz
        if palette.floodIntensity > 0 {
            let flood = Entity()
            flood.components.set(SpotLightComponent(color: palette.floodlight, intensity: palette.floodIntensity,
                                                    innerAngleInDegrees: 35, outerAngleInDegrees: 65, attenuationRadius: 30))
            flood.look(at: [rearX + 2, 0, 0], from: [rearX + 3, 9, 5], relativeTo: nil)
            root.addChild(flood)
        }
    }

    // Yerdeki yığının kapladığı alan | kapının 1,6 m arkasından başlar, dorsenin ortasına hizalı | paletler arası 8 cm
    // ⮕ KULLANIM [stackSpan]: kullanır: buildGround, stackSlot
    private func stackSpan(rearX: Float) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        let pitch = cellSize * SIMD3<Float>(1.08, 1, 1.08)
        let minX = rearX + 1.6
        let depth = pitch.z * Float(Self.stackGrid.z)
        return ([minX, 0, -depth / 2], [minX + pitch.x * Float(Self.stackGrid.x), 0, depth / 2])
    }

    // Yığındaki bir yerin (sütun x, sıra z, kat y) TABAN noktası | 0,06 beton + 0,14 palet
    // ⮕ KULLANIM [stackSlot]: kullanır: buildCargo
    private func stackSlot(x: Int, z: Int, y: Int, rearX: Float) -> SIMD3<Float> {
        let pitch = cellSize * SIMD3<Float>(1.08, 1, 1.08)
        let span = stackSpan(rearX: rearX)
        return [span.min.x + pitch.x * (Float(x) + 0.5), 0.06 + 0.14 + pitch.y * Float(y), span.min.z + pitch.z * (Float(z) + 0.5)]
    }

    // BİR YÜK: sahnedeki varlık + yığındaki yeri (ground) + kasadaki yeri (home)
    struct Load { let entity: Entity; let ground: Transform; let home: Transform }

    // BU FONKSİYON: Yük Veren ile aynı 42 hücre ve aynı karışım; ama her yük kasaya değil YERDEKİ YIĞINA konur, kasadaki yeri "home" olarak saklanır.
    // EŞLEŞTİRME: k'ıncı dolacak hücre (en dipten kapıya, alttan üste) ↔ yığından k'ıncı alınan yer (en üst kat önce, katta kapıya en yakın önce)
    //   → yığından kalkan yükün üstünde ya da önünde yük kalmaz; kasada da yük, henüz boş hücrelerin içinden kayar.
    // ⮕ KULLANIM [buildCargo]: kullanır: build
    private func buildCargo(trailerShell shell: BoundingBox, root: Entity, palette: Palette) async -> [Load] {
        var rng = SeededRandom(seed: 0x7A5E1E) // SABİT TOHUM (15 Kasım, kullanıcı kararı): yükler her açılışta AYNI tür, AYNI yerde ⮕ Design/SeededRandom.swift
        let innerMin = shell.min + SIMD3<Float>(0.14, 0.10, 0.12)
        let cell = cellSize
        let fit = cell * 0.94 // aralarda ince boşluk
        let grid = Self.grid

        // Paletler: yığının her sütununun altında
        let pallet = ModelEntity(mesh: .generateBox(size: [cell.x, 0.14, cell.z], cornerRadius: 0.01),
                                 materials: [SimpleMaterial(color: palette.palletWood, roughness: 0.9, isMetallic: false)])
        for px in 0..<Self.stackGrid.x { for pz in 0..<Self.stackGrid.z {
            let copy = pallet.clone(recursive: true)
            var at = stackSlot(x: px, z: pz, y: 0, rearX: shell.max.x)
            at.y = 0.06 + 0.07
            copy.position = at
            root.addChild(copy)
        } }

        // KALIPLAR + clone [SWIFT]: her türden 1 kalıp, 42 yük bunların kopyası (şekil ve malzeme paylaşılır → ucuz)
        enum Slot { case box, kind(CargoKind) }
        let boxKit = await CardboardBoxKit.prepared(palette: palette) // ⮕ Design/CardboardBoxKit.swift
        let cargoKit = await CargoKit.prepared(palette: palette)      // ⮕ Design/CargoKit.swift
        var boxes: [(entity: Entity, size: SIMD3<Float>)] = []
        for _ in 0..<3 {
            let size = cell * SIMD3<Float>(.random(in: 0.86...0.96, using: &rng), .random(in: 0.84...0.97, using: &rng), .random(in: 0.86...0.96, using: &rng))
            boxes.append((boxKit.makeBox(size: size), size))
            await Task.yield() // [SWIFT] ekran çizimi araya girsin
        }
        var kinds: [CargoKind: Entity] = [:]
        for kind in [CargoKind.orangeCrate, .lemonCrate, .tomatoCrate, .avocadoCrate, .oliveOilTins, .oilBottles, .sacks] {
            kinds[kind] = cargoKit.make(kind, size: fit)
            await Task.yield()
        }
        let layers: [[Slot]] = [ // altta ağırlar, üstte hafifler; her katta koli ağırlıkta (Yük Veren ile aynı)
            [.box, .box, .box, .kind(.oliveOilTins), .kind(.sacks)],
            [.box, .box, .box, .kind(.oilBottles), .kind(.orangeCrate), .kind(.tomatoCrate)],
            [.box, .box, .box, .kind(.lemonCrate), .kind(.avocadoCrate), .kind(.orangeCrate)]
        ]

        // Yığından alma sırası
        var picks: [(x: Int, z: Int, y: Int)] = []
        for y in stride(from: Self.stackGrid.y - 1, through: 0, by: -1) {
            for x in 0..<Self.stackGrid.x { for z in 0..<Self.stackGrid.z { picks.append((x, z, y)) } }
        }
        picks.removeFirst(picks.count - grid.length * grid.height * grid.width) // 45 − 42 = 3 boş: en üst katta (yığının üstü düzensiz görünür)

        var loads: [Load] = []
        var k = 0
        for l in 0..<grid.length {
            for h in 0..<grid.height {
                for w in 0..<grid.width {
                    let item: Entity, size: SIMD3<Float>
                    switch layers[min(h, layers.count - 1)].randomElement(using: &rng)! {
                    case .box:
                        let template = boxes.randomElement(using: &rng)!
                        item = template.entity.clone(recursive: true); size = template.size
                    case .kind(let kind):
                        item = kinds[kind]!.clone(recursive: true); size = fit
                    }
                    let cellMin = innerMin + cell * SIMD3<Float>(Float(l), Float(h), Float(w))
                    let home = Transform(rotation: simd_quatf(angle: .random(in: -0.04...0.04, using: &rng), axis: [0, 1, 0]), // elle dizilmiş gibi hafif yamuk
                                         translation: [cellMin.x + cell.x / 2, cellMin.y + size.y / 2, cellMin.z + cell.z / 2])

                    let p = picks[k]
                    var base = stackSlot(x: p.x, z: p.z, y: p.y, rearX: shell.max.x)
                    base.y += size.y / 2
                    let ground = Transform(rotation: simd_quatf(angle: .random(in: -0.05...0.05, using: &rng), axis: [0, 1, 0]), translation: base)

                    item.transform = ground // başta yerde, yığında
                    root.addChild(item)
                    loads.append(Load(entity: item, ground: ground, home: home))
                    k += 1
                }
            }
        }
        return loads
    }

    // BU FONKSİYON: koreografi. 1) dorse yanaşır 2) yükler sırayla yığından kasaya 3) biter; sonra sahne durur (döngü YOK).
    // YÜKÜN YOLU (forklift gibi, 4 adım): kalk → kapının önüne git (havada) → kapıda kasadaki katının hizasına in → içeri kayıp yerine otur.
    //   Süreler mesafeye göre: dipteki hücreye giden daha uzun kayar.
    // move(to:relativeTo:duration:timingFunction:) [SWIFT]: varlığı hedef Transform'a animasyonla götürür | Task.sleep: adımlar arası bekleme
    // ⮕ KULLANIM [play]: kullanır: build
    private func play(holder: Entity, loads: [Load]) {
        guard !played else { return }
        played = true

        // 1) YANAŞMA: geri geri, yavaşlayarak durur (easeOut) | holder yalnız konumla oynar; yön pivot'ta
        holder.move(to: Transform(translation: .zero), relativeTo: holder.parent, duration: Self.arriveSeconds, timingFunction: .easeOut)

        // 2) YÜKLEME | remaining: biten yük sayacı → hepsi oturunca finish (sahne resme döner, 3B kapanır)
        remaining = loads.count
        let doorX = (loads.map { $0.home.translation.x }.max() ?? 0) + 1.0 // kapının hemen dışı
        for (order, load) in loads.enumerated() {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Self.arriveSeconds + 0.35 + Double(order) * Self.loadInterval))
                let e = load.entity, parent = e.parent
                let g = load.ground.translation, h = load.home.translation
                let lift = max(g.y, h.y) + 0.12 // kalkış yüksekliği: altındaki ve önündeki yüklere değmez

                var up = load.ground
                up.translation.y = lift
                e.move(to: up, relativeTo: parent, duration: 0.22, timingFunction: .easeOut)
                try? await Task.sleep(for: .seconds(0.22))

                let door = Transform(rotation: load.home.rotation, translation: [doorX, lift, h.z])
                let toDoor = Double(0.15 + simd_distance(up.translation, door.translation) * 0.07)
                e.move(to: door, relativeTo: parent, duration: toDoor, timingFunction: .easeInOut)
                try? await Task.sleep(for: .seconds(toDoor))

                let atDoor = Transform(rotation: load.home.rotation, translation: [doorX, h.y, h.z])
                e.move(to: atDoor, relativeTo: parent, duration: 0.14, timingFunction: .easeInOut)
                try? await Task.sleep(for: .seconds(0.14))

                let slide = Double(0.18 + (doorX - h.x) * 0.06)
                e.move(to: load.home, relativeTo: parent, duration: slide, timingFunction: .easeOut) // sona doğru yavaşlar: "yerine oturdu"
                try? await Task.sleep(for: .seconds(slide))
                self.remaining -= 1
                if self.remaining == 0 { self.finish?(); self.finish = nil } // 3) DURDU → ⮕ StillScene: fotoğraf + 3B kapanır
            }
        }
    }
}
