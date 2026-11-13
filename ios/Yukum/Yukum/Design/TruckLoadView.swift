//
//  TruckLoadView.swift
//  Yukum
//
//  Kasası şeffaf kamyon: progress (0…1) arttıkça kasaya koliler dizilir. Yük Veren ekranları için.
//

import SwiftUI    // [SWIFT] ekran çizim kütüphanesi
import RealityKit // [SWIFT] Apple'ın 3B motoru (iOS'un içinde, ek kütüphane yok)
import UIKit      // [SWIFT] UIColor buradan gelir

// ┌─ BAĞLANTI HARİTASI: TruckLoadView.swift ─────────────────────────────────────────
// │ GELEN     : (henüz ekrana bağlı değil) TruckLoadPreview → App/ContentView.swift "-truckPreview" argümanıyla (yalnız DEBUG)
// │ GİDEN     : Design/Truck.usdz (hazır 3B model: "Truck" by ROY, Sketchfab, CC-BY 4.0 → uygulamada atıf GEREKİR)
// │             Design/CardboardBoxKit.swift (koliler) | Design/DesignPalette.swift (renkler)
// │ TEKNİK    : RealityKit. Kamyon HAZIR MODEL (kodla çizilmedi); kod yalnız yükler, boyar, kasayı şeffaflaştırır, kolileri dizer.
// │ REHBER    : Design/00_Rehber_Design.swift
// └──────────────────────────────────────────────────────────────────────
//
// ZİNCİR:
//   Ekran: TruckLoadView(progress: 0.6)  →  RealityView.make (1 kez): sahne + model yüklenir (TruckLoadRig.build)
//   progress değişir → RealityView.update → rig.setProgress(0.6) → 42 kolinin ilk 25'i görünür olur;
//   yeni görünenler yukarıdan yerine "oturur" (move animasyonu). progress azalırsa fazla koliler kaybolur.
//
// NASIL "kasaya doluyor":
//   1. Modelde kasa tek parça ve malzemesinin adı "bodycolour" (terminalde: usdcat Truck.usdz). O malzeme şeffaf camla değiştirilir.
//   2. Kasanın sahnedeki sınır kutusu ölçülür (visualBounds) → içi 7 × 3 × 2 hücreye bölünür → her hücreye bir koli konur (başta gizli).
//   3. Koliler kamyonun ÇOCUĞU: kamyon hareket ederse onunla gider.
// NEDEN fizik yok (giriş ekranındaki gibi): burada koliler DÜZGÜN dizilmeli ("yük yerleşti" hissi) ve progress'e birebir bağlı olmalı;
//   fizik her seferinde farklı sonuç verir, geri alınamaz.

// ⮕ KULLANIM [TruckLoadView]: kullanır: TruckLoadPreview › body (ileride: CreateListingView / HomeView)
struct TruckLoadView: View { // TruckLoadView [BİZİM] ad | View [SWIFT]: bu bir ekran parçası
    var progress: Double // kasanın doluluk oranı: 0 = boş, 1 = tam dolu

    @Environment(\.colorScheme) private var colorScheme // [SWIFT] telefon açık modda mı koyu modda mı
    @State private var rig = TruckLoadRig() // [BİZİM] modeli ve kolileri tutan nesne (aşağıda)

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View {
        RealityView { content in // make: 1 kez çalışır
            content.camera = .virtual // [SWIFT] AR değil: sanal kamera
            rig.build(in: &content, palette: Palette(isDark: colorScheme == .dark))
            rig.setProgress(progress)
        } update: { _ in // update [SWIFT]: bu görünümün okuduğu bir değer (progress) değişince çalışır
            rig.setProgress(progress)
        }
    }
}

// BU SINIF: kamyon modelini yükler, boyar, kasaya kolileri hazırlar; progress'e göre kolileri gösterir/gizler.
// NEDEN class: model eşzamansız yüklenir; yüklenince aynı nesneye yazabilmek için (struct kopyalanırdı).
// ⮕ KULLANIM [TruckLoadRig]: kullanır: TruckLoadView › rig
@MainActor
final class TruckLoadRig {
    static let truckLength: Float = 8.5 // aracın sahnedeki boyu (m)
    static let grid = (length: 7, height: 3, width: 2) // kasadaki koli düzeni: boyuna 7 × yukarı 3 × enine 2 = 42 koli

    private var cargo: [(box: Entity, home: Transform)] = [] // koliler ve kasadaki yerleri (home = oturacağı konum)
    private var shownCount = 0       // şu an görünen koli sayısı
    private var pendingProgress = 0.0 // model yüklenmeden gelen progress burada bekler

    // ⮕ KULLANIM [build]: kullanır: TruckLoadView › RealityView.make (1 kez)
    func build(in content: inout RealityViewCameraContent, palette: Palette) {
        let root = Entity()
        content.add(root)

        // 1) SAHNE: aracın durduğu yuvarlak koyu platform (vitrin podyumu). Düz zemin yerine disk: kenarı ufuk çizgisi gibi sırıtmaz.
        var podium = PhysicallyBasedMaterial()
        podium.baseColor = .init(tint: palette.podium)
        podium.roughness = 0.35
        let disc = ModelEntity(mesh: .generateCylinder(height: 0.06, radius: 5.6), materials: [podium])
        disc.position.y = -0.03
        root.addChild(disc)

        // 2) IŞIKLAR: önden sıcak beyaz (gölge bundan), arkadan iki renkli kenar ışığı.
        let key = Entity()
        key.components.set(DirectionalLightComponent(color: palette.keyLight, intensity: palette.keyIntensity))
        key.components.set(DirectionalLightComponent.Shadow(maximumDistance: 40, depthBias: 2))
        key.look(at: [0, 1.5, 0], from: [-4, 9, 8], relativeTo: nil)
        root.addChild(key)
        for (from, color) in [(SIMD3<Float>(-8, 5, -6), palette.rimA), (SIMD3<Float>(8, 6, -6), palette.rimB)] {
            let rim = Entity()
            rim.components.set(SpotLightComponent(color: color, intensity: palette.rimIntensity,
                                                  innerAngleInDegrees: 50, outerAngleInDegrees: 80, attenuationRadius: 40))
            rim.look(at: [0, 2, 0], from: from, relativeTo: nil)
            root.addChild(rim)
        }

        // 3) KAMERA: yandan, hafif önden ve yukarıdan → kasanın uzun yüzü tam görünür (koliler buradan seyredilir).
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 32
        camera.look(at: [0.2, 1.75, 0], from: [-4.5, 3.4, 15.5], relativeTo: nil)
        root.addChild(camera)

        // 4) MODEL: eşzamansız yüklenir; gelince ölçülür, boyanır, kasası şeffaflaşır, koliler hazırlanır.
        let kit = CardboardBoxKit(palette: palette)
        Task { @MainActor in
            guard let truck = try? await Entity(named: "Truck") else { return } // Design/Truck.usdz
            let holder = Entity() // modeli saran boş kutu: konum/ölçek buna verilir
            holder.addChild(truck)

            // Ölçüyü sabitle: en uzun kenar 8,5 m; uzun eksen X'e (ekranda yatay) çevrilir; tekerlekler y = 0'a oturur.
            let bounds = truck.visualBounds(relativeTo: holder) // [SWIFT] modelin kapladığı görünür kutu
            truck.scale *= SIMD3(repeating: Self.truckLength / max(max(bounds.extents.x, bounds.extents.z), 0.001))
            if bounds.extents.z > bounds.extents.x {
                truck.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0]) * truck.orientation
            }
            let fitted = truck.visualBounds(relativeTo: holder)
            truck.position -= [fitted.center.x, fitted.min.y, fitted.center.z]

            let cargoShell = self.repaint(truck, palette: palette) // boyar; kasa parçasını (bodycolour) geri verir
            root.addChild(holder)

            if let cargoShell {
                self.buildCargo(inside: cargoShell.visualBounds(relativeTo: holder), parent: holder, kit: kit, palette: palette)
            }
            self.setProgress(self.pendingProgress) // model gelmeden istenen doluluk şimdi uygulanır
        }
    }

    // BU FONKSİYON: malzemeleri ADLARINA göre bulup değiştirir. Kasa malzemesini taşıyan parçayı geri döndürür.
    // Malzeme adları modelin içinden okundu (usdcat): head_paint = kabin boyası, bodycolour = kasa, glass/windglass = camlar, signal_light = farlar.
    // ⮕ KULLANIM [repaint]: kullanır: build
    private func repaint(_ entity: Entity, palette: Palette) -> Entity? {
        var cargoShell: Entity?
        if var model = entity.components[ModelComponent.self] { // [SWIFT] ModelComponent: parçanın şekli + malzemeleri
            model.materials = model.materials.map { material in
                switch material.name { // [SWIFT] malzemenin dosyadaki adı (iOS 18+)
                case "head_paint": // kabin: araba boyası + vernik
                    var paint = PhysicallyBasedMaterial()
                    paint.baseColor = .init(tint: palette.cabPaint)
                    paint.metallic = 0.25
                    paint.roughness = 0.3
                    paint.clearcoat = .init(floatLiteral: 1.0)
                    paint.clearcoatRoughness = .init(floatLiteral: 0.06)
                    return paint
                case "bodycolour": // KASA: şeffaf cam → içindeki koliler görünür
                    cargoShell = entity
                    var glass = PhysicallyBasedMaterial()
                    glass.baseColor = .init(tint: palette.cargoGlass)
                    glass.roughness = 0.05
                    glass.clearcoat = .init(floatLiteral: 1.0)
                    glass.blending = .transparent(opacity: .init(floatLiteral: 0.16)) // [SWIFT] %16 opak = neredeyse saydam
                    return glass
                case "glass", "windglass", "full_glass": // kabin camları: koyu füme
                    var glass = PhysicallyBasedMaterial()
                    glass.baseColor = .init(tint: UIColor(red: 0.02, green: 0.02, blue: 0.025, alpha: 1))
                    glass.roughness = 0.04
                    glass.clearcoat = .init(floatLiteral: 1.0)
                    return glass
                case "signal_light", "signal_light_001": // farlar: kendi ışığını yayar
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
        for child in entity.children { // alt parçalara in (özyineleme)
            if let found = repaint(child, palette: palette) { cargoShell = found }
        }
        return cargoShell
    }

    // BU FONKSİYON: kasanın içini hücrelere böler, her hücreye bir koli koyar (başta gizli) ve kasa kenarlarına ince parlak çerçeve çizer.
    // ⮕ KULLANIM [buildCargo]: kullanır: build
    private func buildCargo(inside shell: BoundingBox, parent: Entity, kit: CardboardBoxKit, palette: Palette) {
        // Kasa çerçevesi: sınır kutusunun 12 kenarına ince ışıklı çubuklar → şeffaf kasanın hatları belli olur.
        let edgeMaterial = UnlitMaterial(color: palette.cargoEdge)
        let t: Float = 0.035 // çubuk kalınlığı
        let e = shell.extents, c = shell.center
        for sy: Float in [-1, 1] { for sz: Float in [-1, 1] { // boyuna 4 kenar
            let bar = ModelEntity(mesh: .generateBox(size: [e.x, t, t]), materials: [edgeMaterial])
            bar.position = [c.x, c.y + sy * e.y / 2, c.z + sz * e.z / 2]; parent.addChild(bar)
        } }
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] { // dikey 4 kenar
            let bar = ModelEntity(mesh: .generateBox(size: [t, e.y, t]), materials: [edgeMaterial])
            bar.position = [c.x + sx * e.x / 2, c.y, c.z + sz * e.z / 2]; parent.addChild(bar)
        } }
        for sx: Float in [-1, 1] { for sy: Float in [-1, 1] { // enine 4 kenar
            let bar = ModelEntity(mesh: .generateBox(size: [t, t, e.z]), materials: [edgeMaterial])
            bar.position = [c.x + sx * e.x / 2, c.y + sy * e.y / 2, c.z]; parent.addChild(bar)
        } }

        // Kullanılabilir iç hacim: duvarlardan biraz içeride, tavandan biraz aşağıda.
        let innerMin = shell.min + SIMD3<Float>(0.14, 0.10, 0.12)
        let innerMax = shell.max - SIMD3<Float>(0.14, 0.30, 0.12)
        let grid = Self.grid
        let cell = (innerMax - innerMin) / SIMD3<Float>(Float(grid.length), Float(grid.height), Float(grid.width))

        // Dizme sırası: önce bir dilimin altı-üstü dolar, sonra yandaki dilime geçilir (gerçek yükleme gibi: dipten kapıya doğru).
        for l in 0..<grid.length {
            for h in 0..<grid.height {
                for w in 0..<grid.width {
                    let jitter = SIMD3<Float>(.random(in: 0.86...0.96), .random(in: 0.84...0.97), .random(in: 0.86...0.96)) // koliler birebir aynı olmasın
                    let size = cell * jitter
                    let box = kit.makeBox(size: size)
                    let cellMin = innerMin + cell * SIMD3<Float>(Float(l), Float(h), Float(w))
                    box.position = [cellMin.x + cell.x / 2, cellMin.y + size.y / 2, cellMin.z + cell.z / 2] // hücrenin TABANINA oturur
                    box.orientation = simd_quatf(angle: .random(in: -0.05...0.05), axis: [0, 1, 0]) // çok hafif yamuk: elle dizilmiş gibi
                    box.isEnabled = false // [SWIFT] gizli (çizilmez); setProgress sırası gelince açar
                    parent.addChild(box)
                    cargo.append((box, box.transform))
                }
            }
        }
    }

    // BU FONKSİYON: doluluk oranını koli sayısına çevirir; eksikse sıradaki kolileri yerine oturtur, fazlaysa gizler.
    // ⮕ KULLANIM [setProgress]: kullanır: TruckLoadView › make / update, build (model yüklenince)
    func setProgress(_ progress: Double) {
        pendingProgress = progress
        guard !cargo.isEmpty else { return } // model henüz yüklenmedi
        let target = Int((min(max(progress, 0), 1) * Double(cargo.count)).rounded())

        if target > shownCount {
            for (order, index) in (shownCount..<target).enumerated() {
                let item = cargo[index]
                var start = item.home
                start.translation.y += 1.1          // biraz yukarıdan
                start.scale = SIMD3(repeating: 0.75) // biraz küçük başlar
                item.box.transform = start
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(Double(order) * 0.07)) // art arda gelenler sırayla insin
                    item.box.isEnabled = true
                    item.box.move(to: item.home, relativeTo: item.box.parent, duration: 0.38, timingFunction: .easeOut) // [SWIFT] hedef konuma animasyonla git
                }
            }
        } else if target < shownCount {
            for index in target..<shownCount { cargo[index].box.isEnabled = false }
        }
        shownCount = target
    }
}

#if DEBUG
// PROTOTİP: kamyonu tek başına görmek için. Doluluk kendiliğinden artar; alttaki sürgüyle elle de oynanır.
// Çalıştırma: Xcode → Edit Scheme → Run → Arguments → "-truckPreview". Ekrana bağlanınca bu blok ve ContentView'daki kapı silinir.
// ⮕ KULLANIM [TruckLoadPreview]: kullanır: ContentView › body (yalnız DEBUG + "-truckPreview")
struct TruckLoadPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var progress = 0.0

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        ZStack {
            LinearGradient(colors: [palette.skyTop, palette.skyBottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("Yük dolumu: %\(Int(progress * 100))").font(.title2.bold()).foregroundStyle(palette.title)
                TruckLoadView(progress: progress).frame(height: 330)
                Slider(value: $progress).tint(palette.accent).padding(.horizontal, 30)
                Spacer()
            }
            .padding(.top, 30)
        }
        .task { // açılınca kendiliğinden doldur
            try? await Task.sleep(for: .seconds(1.5))
            for step in 1...10 {
                progress = Double(step) / 10
                try? await Task.sleep(for: .seconds(0.55))
            }
        }
    }
}
#endif
