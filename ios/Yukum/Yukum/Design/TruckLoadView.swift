//
//  TruckLoadView.swift
//  Yukum
//
//  Kasası şeffaf tır dorsesi: progress (0…1) arttıkça kasaya yükler dizilir (koli, meyve kasası, zeytinyağı, çuval...).
//  Yük Veren ana ekranının arka planı.
//

import SwiftUI    // [SWIFT] ekran çizim kütüphanesi
import RealityKit // [SWIFT] Apple'ın 3B motoru (iOS'un içinde, ek kütüphane yok)
import UIKit      // [SWIFT] UIColor buradan gelir

// ┌─ BAĞLANTI HARİTASI: TruckLoadView.swift ─────────────────────────────────────────
// │ GELEN     : Views/HomeView.swift › shipperBackground (Yük Veren ana ekranı, tam ekran arka plan)
// │             Views/LoginView.swift › TruckModel.preload() (modeli giriş ekranındayken önceden yükler)
// │             TruckLoadPreview → App/ContentView.swift "-truckPreview" (yalnız DEBUG)
// │ GİDEN     : Design/Truck.usdz (hazır 3B model: "Truck" by ROY, Sketchfab, CC-BY 4.0 → uygulamada atıf GEREKİR: Views/PrivacyView › Atıflar)
// │             Design/CardboardBoxKit.swift (karton koli: yüklerin çoğu) | Design/CargoKit.swift (meyve/sebze kasaları, zeytinyağı tenekesi ve şişesi, çuval) | Design/DesignPalette.swift
// │ TEKNİK    : RealityKit. Model HAZIR (kodla çizilmedi); kod yalnız kabini çıkarır, boyar, kasayı şeffaflaştırır, yükleri dizer.
// │ REHBER    : Design/00_Rehber_Design.swift
// └──────────────────────────────────────────────────────────────────────
//
// ZİNCİR:
//   Giriş ekranı açılır → TruckModel.preload(): model ARKA PLANDA yüklenmeye başlar (kullanıcı şifre yazarken)
//   Ana ekran → TruckLoadView(progress: 1) → RealityView.make: sahne kurulur → TruckModel.instance(): hazır modelin kopyası
//   → trailerOnly: kabin ve kabinin tekerleri çıkarılır → ölçeklenir, boyanır → buildCargo: yük kalıpları + 42 kopya (başta gizli)
//   → setProgress(1): yükler sırayla yukarıdan yerine "oturur". Bir kez oynar, kalır.
//
// NEDEN önceden yükleme (13 Kasım ölçümü, App/PerfLog): model iPhone 11'de 3,9 sn'de yükleniyordu ve bu süre ana ekran açıldıktan SONRA başlıyordu.
//   Giriş ekranında kullanıcı zaten birkaç saniye geçirir → yükleme o sürede biter, ana ekranda dorse hemen gelir.
// NEDEN fizik yok (giriş ekranındaki gibi): yükler DÜZGÜN dizilmeli ("yük yerleşti" hissi) ve progress'e birebir bağlı olmalı.

// BU TÜR: kamyon modelini BİR KEZ yükler ve saklar; isteyene kopyasını verir.
// NEDEN Task saklanıyor: preload ile instance aynı yüklemeyi bekler; ikinci kez yüklenmez.
// ⮕ KULLANIM [TruckModel]: kullanır: LoginView › .task (preload), TruckLoadRig › build (instance)
@MainActor
enum TruckModel {
    private static var loading: Task<Entity?, Never>? // [SWIFT] Task: arka planda süren iş; .value ile sonucu beklenir

    // Yüklemeyi başlatır (zaten başladıysa bir şey yapmaz)
    static func preload() {
        guard loading == nil else { return }
        loading = Task { try? await Entity(named: "Truck") } // Design/Truck.usdz
    }

    // Modelin KOPYASINI verir (yükleme bitmediyse bitmesini bekler) | clone: şekil ve dokular paylaşılır, ucuz
    static func instance() async -> Entity? {
        preload()
        return await loading?.value?.clone(recursive: true)
    }
}

// ⮕ KULLANIM [TruckLoadView]: kullanır: HomeView › shipperBackground, TruckLoadPreview › body
struct TruckLoadView: View { // TruckLoadView [BİZİM] ad | View [SWIFT]: bu bir ekran parçası
    var progress: Double // kasanın doluluk oranı: 0 = boş, 1 = tam dolu

    @Environment(\.colorScheme) private var colorScheme // [SWIFT] telefon açık modda mı koyu modda mı
    @State private var rig = TruckLoadRig() // [BİZİM] modeli ve yükleri tutan nesne (aşağıda)

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

// BU SINIF: sahneyi kurar, modeli dorseye çevirir, kasaya yükleri hazırlar; progress'e göre gösterir/gizler.
// NEDEN class: model eşzamansız gelir; gelince aynı nesneye yazabilmek için (struct kopyalanırdı).
// ⮕ KULLANIM [TruckLoadRig]: kullanır: TruckLoadView › rig
@MainActor
final class TruckLoadRig {
    static let trailerLength: Float = 8.0 // dorsenin sahnedeki boyu (m)
    static let grid = (length: 7, height: 3, width: 2) // kasadaki düzen: boyuna 7 × yukarı 3 × enine 2 = 42 hücre

    private var cargo: [(box: Entity, home: Transform)] = [] // yükler ve kasadaki yerleri (home = oturacağı konum)
    private var shownCount = 0       // şu an görünen yük sayısı
    private var pendingProgress = 0.0 // model gelmeden istenen progress burada bekler

    // ⮕ KULLANIM [build]: kullanır: TruckLoadView › RealityView.make (1 kez)
    func build(in content: inout RealityViewCameraContent, palette: Palette) {
        let root = Entity()
        content.add(root)

        // 1) SAHNE ZEMİNİ YOK (14 Kasım, kullanıcı isteği): önceden dorse yuvarlak bir podyumun üstündeydi → "ayrı bir sahne" gibi duruyordu.
        //    Şimdi dorse doğrudan ekranın arka planında (HomeView'ın renk geçişi üstünde) durur.

        // 2) IŞIKLAR (kullanıcı isteği: daha parlak): önden güçlü sıcak beyaz (gölge bundan) + sağ-önden dolgu (gölgeli yüzler kararmasın)
        //    + arkadan iki renkli kenar ışığı (dorsenin hatları zeminden ayrılsın). Güçler DesignPalette'te.
        let key = Entity()
        key.components.set(DirectionalLightComponent(color: palette.keyLight, intensity: palette.trailerKeyIntensity))
        key.components.set(DirectionalLightComponent.Shadow(maximumDistance: 40, depthBias: 2))
        key.look(at: [0, 1.5, 0], from: [-4, 9, 8], relativeTo: nil)
        root.addChild(key)
        let fill = Entity()
        fill.components.set(DirectionalLightComponent(color: palette.keyLight, intensity: palette.trailerFillIntensity)) // gölgesiz
        fill.look(at: [0, 1.5, 0], from: [7, 3, 9], relativeTo: nil)
        root.addChild(fill)
        for (from, color) in [(SIMD3<Float>(-8, 5, -6), palette.rimA), (SIMD3<Float>(8, 6, -6), palette.rimB)] {
            let rim = Entity()
            rim.components.set(SpotLightComponent(color: color, intensity: palette.rimIntensity,
                                                  innerAngleInDegrees: 50, outerAngleInDegrees: 80, attenuationRadius: 40))
            rim.look(at: [0, 2, 0], from: from, relativeTo: nil)
            root.addChild(rim)
        }

        // 3) KAMERA: yandan, hafif önden ve yukarıdan → kasanın uzun yüzü tam görünür (yükler buradan seyredilir).
        //    fieldOfViewOrientation = .horizontal [SWIFT]: görüş açısı ekranın ENİNE göre → telefon ne kadar uzun olursa olsun dorse yatayda sığar.
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewOrientation = .horizontal
        camera.camera.fieldOfViewInDegrees = 44
        camera.look(at: [0.3, 1.7, 0], from: [-5.0, 3.6, 13.5], relativeTo: nil)
        root.addChild(camera)

        // 4) MODEL + YÜKLER: model önceden yüklendiyse hemen gelir; yükler bekletmeden hazırlanır.
        Task { @MainActor in
            PerfLog.mark("dorse: sahne kuruldu (make)") // GEÇİCİ ölçüm ⮕ App/PerfLog.swift
            guard let truck = await TruckModel.instance() else { return }
            PerfLog.mark("dorse: model hazır (önceden yüklendiyse ~0)")
            let holder = Entity() // modeli saran boş kutu: konum/ölçek buna verilir
            holder.addChild(truck)
            self.trailerOnly(truck)

            // Ölçüyü sabitle: dorsenin en uzun kenarı 8 m; uzun eksen X'e (ekranda yatay) çevrilir; tekerlekler y = 0'a oturur; ortalanır.
            let bounds = truck.visualBounds(relativeTo: holder) // [SWIFT] modelin kapladığı görünür kutu
            truck.scale *= SIMD3(repeating: Self.trailerLength / max(max(bounds.extents.x, bounds.extents.z), 0.001))
            if bounds.extents.z > bounds.extents.x {
                truck.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0]) * truck.orientation
            }
            let fitted = truck.visualBounds(relativeTo: holder)
            truck.position -= [fitted.center.x, fitted.min.y, fitted.center.z]

            let cargoShell = self.repaint(truck, palette: palette) // boyar; kasa parçasını (bodycolour) geri verir
            root.addChild(holder)
            PerfLog.mark("dorse: kabin çıkarıldı, boyandı")

            if let cargoShell {
                await self.buildCargo(inside: cargoShell.visualBounds(relativeTo: holder), parent: holder, palette: palette)
            }
            PerfLog.mark("dorse: 42 yük kuruldu")
            self.setProgress(self.pendingProgress) // model gelmeden istenen doluluk şimdi uygulanır
        }
    }

    // BU FONKSİYON: modelden KABİNİ ve kasanın önünde kalan her şeyi (kabin tekerleri, egzoz...) çıkarır → geriye yalnız dorse kalır.
    // NASIL: modelde kabin "Truck_head..." adlı ayrı parça, kasa "Truck_body..." (terminalde: usdcat Truck.usdz).
    //   Tekerler ise ayrı gruplar ("Empty_0xx"), hangisinin kabine ait olduğu adından belli değil → KONUMA bakılır:
    //   ortası kasanın boyunun dışında kalan parça (kasanın önünde/arkasında) çıkarılır.
    // ⮕ KULLANIM [trailerOnly]: kullanır: build
    private func trailerOnly(_ truck: Entity) {
        truck.findEntity(named: "Truck_head_Truck_head_L_1")?.removeFromParent() // [SWIFT] findEntity: alt parçalarda adla arar
        guard let body = truck.findEntity(named: "Truck_body_Truck_body_L_3") else { return }
        let shell = body.visualBounds(relativeTo: truck)
        let alongX = shell.extents.x > shell.extents.z // kasanın uzun ekseni (modelin kendi ekseninde)
        let low = (alongX ? shell.min.x : shell.min.z) - 0.05, high = (alongX ? shell.max.x : shell.max.z) + 0.05

        // Tüm şekilli parçaları gez; kasanın içindekilere dokunma, ortası kasa boyunun dışındakini çıkar
        var outside: [Entity] = []
        func visit(_ entity: Entity) {
            if entity === body { return } // kasanın kendisi ve alt parçaları kalır
            if entity.components.has(ModelComponent.self) {
                let center = entity.visualBounds(relativeTo: truck).center
                let along = alongX ? center.x : center.z
                if along < low || along > high { outside.append(entity); return }
            }
            for child in entity.children { visit(child) }
        }
        visit(truck)
        for entity in outside { entity.removeFromParent() } // gezerken değil, sonra sil (gezilen liste değişmesin)
    }

    // BU FONKSİYON: malzemeleri ADLARINA göre bulup değiştirir. Kasa malzemesini taşıyan parçayı geri döndürür.
    // Malzeme adları modelin içinden okundu (usdcat): bodycolour = kasa, glass/windglass = camlar, signal_light = lambalar.
    // ⮕ KULLANIM [repaint]: kullanır: build
    private func repaint(_ entity: Entity, palette: Palette) -> Entity? {
        var cargoShell: Entity?
        if var model = entity.components[ModelComponent.self] { // [SWIFT] ModelComponent: parçanın şekli + malzemeleri
            model.materials = model.materials.map { material in
                switch material.name { // [SWIFT] malzemenin dosyadaki adı (iOS 18+)
                case "bodycolour": // KASA: şeffaf cam → içindeki yükler görünür
                    cargoShell = entity
                    var glass = PhysicallyBasedMaterial()
                    glass.baseColor = .init(tint: palette.cargoGlass)
                    glass.roughness = 0.05
                    glass.clearcoat = .init(floatLiteral: 1.0)
                    glass.blending = .transparent(opacity: .init(floatLiteral: 0.07)) // [SWIFT] %7 opak | %14-16'da yükler soluk (sütlü) görünüyordu
                    return glass
                case "glass", "windglass", "full_glass": // camlar: koyu füme
                    var glass = PhysicallyBasedMaterial()
                    glass.baseColor = .init(tint: UIColor(red: 0.02, green: 0.02, blue: 0.025, alpha: 1))
                    glass.roughness = 0.04
                    glass.clearcoat = .init(floatLiteral: 1.0)
                    return glass
                case "signal_light", "signal_light_001": // lambalar: kendi ışığını yayar
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

    // BU FONKSİYON: kasanın içini hücrelere böler, her hücreye bir yük koyar (başta gizli) ve kasa kenarlarına ince parlak çerçeve çizer.
    // YÜK KARIŞIMI (kullanıcı isteği: "envai çeşit", tarım ürünleri): altta ağırlar (çuval, teneke, şişe), üstte hafifler (meyve kasası, koli).
    // NEDEN KALIP + clone (13 Kasım gecikme düzeltmesi): her türden 1 kalıp üretilir, 42 hücre bunlardan kopyalanır.
    //   clone(recursive:) [SWIFT]: şekil ve malzeme PAYLAŞILIR, yeniden üretilmez → çok ucuz. Kalıplar arasında Task.yield() → ekran nefes alır.
    // ⮕ KULLANIM [buildCargo]: kullanır: build
    private func buildCargo(inside shell: BoundingBox, parent: Entity, palette: Palette) async {
        // Kasa çerçevesi: sınır kutusunun 12 kenarına ince ışıklı çubuklar → şeffaf kasanın hatları belli olur.
        let edgeMaterial = UnlitMaterial(color: palette.cargoEdge) // [SWIFT] ışıktan etkilenmez → hep parlak
        let t: Float = 0.04 // çubuk kalınlığı
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
        let fit = cell * 0.94 // yük hücreyi tam doldurmasın: aralarda ince boşluk

        // KALIPLAR: karton koli (3 ölçü) + her ürün türünden 1
        // 14 Kasım kullanıcı kararı: "tırın geneli KOLİ olacak" → yüklerin çoğu karton koli, aralarında meyve kasası, zeytinyağı, çuval.
        enum Slot { case box, kind(CargoKind) } // [SWIFT] iç içe tür: bu fonksiyona özel | box = karton koli
        let boxKit = await CardboardBoxKit.prepared(palette: palette) // ⮕ Design/CardboardBoxKit.swift (koli dokuları, bekletmeden)
        let cargoKit = await CargoKit.prepared(palette: palette)      // ⮕ Design/CargoKit.swift (ürün dokuları arka planda çizilir)
        PerfLog.mark("dorse: dokular hazır")
        var boxes: [(entity: Entity, size: SIMD3<Float>)] = []
        for _ in 0..<3 {
            let size = cell * SIMD3<Float>(.random(in: 0.86...0.96), .random(in: 0.84...0.97), .random(in: 0.86...0.96))
            boxes.append((boxKit.makeBox(size: size), size))
            await Task.yield() // [SWIFT] "sıranı ver": bekleyen ekran çizimi araya girer
        }
        var kinds: [CargoKind: Entity] = [:]
        for kind in [CargoKind.orangeCrate, .lemonCrate, .tomatoCrate, .avocadoCrate, .oliveOilTins, .oilBottles, .sacks] {
            kinds[kind] = cargoKit.make(kind, size: fit)
            await Task.yield()
        }
        PerfLog.mark("dorse: yük kalıpları hazır")

        // Katlara göre olası yükler | her katta koli ağırlıkta (~%60) | altta ağır ürünler, üstte meyve kasaları
        let layers: [[Slot]] = [
            [.box, .box, .box, .kind(.oliveOilTins), .kind(.sacks)],                                  // alt kat
            [.box, .box, .box, .kind(.oilBottles), .kind(.orangeCrate), .kind(.tomatoCrate)],          // orta kat
            [.box, .box, .box, .kind(.lemonCrate), .kind(.avocadoCrate), .kind(.orangeCrate)]          // üst kat
        ]

        // Dizme sırası: önce bir dilimin altı-üstü dolar, sonra yandaki dilime geçilir (gerçek yükleme gibi: dipten kapıya doğru).
        for l in 0..<grid.length {
            for h in 0..<grid.height {
                for w in 0..<grid.width {
                    let item: Entity, size: SIMD3<Float>
                    switch layers[min(h, layers.count - 1)].randomElement()! {
                    case .box:
                        let template = boxes.randomElement()!
                        item = template.entity.clone(recursive: true); size = template.size // kalıptan kopya (bant, etiket dahil)
                    case .kind(let kind):
                        item = kinds[kind]!.clone(recursive: true); size = fit             // kalıptan kopya: şekil ve malzeme paylaşılır
                    }
                    let cellMin = innerMin + cell * SIMD3<Float>(Float(l), Float(h), Float(w))
                    item.position = [cellMin.x + cell.x / 2, cellMin.y + size.y / 2, cellMin.z + cell.z / 2] // hücrenin TABANINA oturur
                    item.orientation = simd_quatf(angle: .random(in: -0.04...0.04), axis: [0, 1, 0]) // çok hafif yamuk: elle dizilmiş gibi
                    item.isEnabled = false // [SWIFT] gizli (çizilmez); setProgress sırası gelince açar
                    parent.addChild(item)
                    cargo.append((item, item.transform))
                }
            }
        }
    }

    // BU FONKSİYON: doluluk oranını yük sayısına çevirir; eksikse sıradaki yükleri yerine oturtur, fazlaysa gizler.
    // ⮕ KULLANIM [setProgress]: kullanır: TruckLoadView › make / update, build (yükler hazır olunca)
    func setProgress(_ progress: Double) {
        pendingProgress = progress
        guard !cargo.isEmpty else { return } // yükler henüz hazırlanmadı
        let target = Int((min(max(progress, 0), 1) * Double(cargo.count)).rounded())

        if target > shownCount {
            for (order, index) in (shownCount..<target).enumerated() {
                let item = cargo[index]
                var start = item.home
                start.translation.y += 1.1          // biraz yukarıdan
                start.scale = SIMD3(repeating: 0.75) // biraz küçük başlar
                item.box.transform = start
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(Double(order) * 0.05)) // art arda gelenler sırayla insin (42 × 0,05 ≈ 2 sn)
                    item.box.isEnabled = true
                    if order == 0 { PerfLog.mark("dorse: ilk yük göründü") } // GEÇİCİ ölçüm
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
// PROTOTİP: dorseyi tek başına görmek için. Doluluk kendiliğinden artar; alttaki sürgüyle elle de oynanır.
// Çalıştırma: Xcode → Edit Scheme → Run → Arguments → "-truckPreview".
// ⮕ KULLANIM [TruckLoadPreview]: kullanır: ContentView › body (yalnız DEBUG + "-truckPreview")
struct TruckLoadPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var progress = 0.0

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        ZStack { // ana ekrandaki gibi: dorse TÜM EKRANIN arkasında, yazı ve sürgü üstünde
            LinearGradient(colors: [palette.skyTop, palette.skyBottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            TruckLoadView(progress: progress).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("Yük dolumu: %\(Int(progress * 100))").font(.title2.bold()).foregroundStyle(palette.title)
                Spacer()
                Slider(value: $progress).tint(palette.accent).padding(.horizontal, 30)
            }
            .padding(.vertical, 30)
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
