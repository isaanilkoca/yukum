//
//  LoginBoxDrop.swift
//  Yukum
//
//  Giriş ekranı: formun ALTINDAKİ boş alana tek bir Yüküm kolisi düşer, hafifçe seker, oturur; sonra resme döner (3B kapanır).
//  Bantlarda "YÜKÜM" yazısı: kapak bandı + ortadan dolanan marka bandı — uygulama simgesindeki kutunun 3B hali (15 Kasım).
//

import SwiftUI    // [SWIFT] ekran çizim kütüphanesi
import RealityKit // [SWIFT] 3B motor (yalnız düşüş süresince; sonra StillScene resme çevirir)
import UIKit      // [SWIFT] UIImage, UIGraphicsImageRenderer (bant dokusu)
import Combine    // [SWIFT] Cancellable: kare aboneliği

// ┌─ BAĞLANTI HARİTASI: LoginBoxDrop.swift ─────────────────────────────────────────
// │ GELEN     : Views/LoginView.swift (form kartının altında, sabit yükseklikli alan)
// │ GİDEN     : Design/StillScene.swift (bir kez oynat → resim) | Design/CardboardBoxKit.swift (koli gövdesi, önbellekli)
// │             Design/CardboardArt.swift › textureAsync | Design/YukumLogo.swift (etiketteki logo) | Design/DesignPalette.swift
// │ REHBER    : Design/00_Rehber_Design.swift
// └──────────────────────────────────────────────────────────────────────
//
// SON HALİ (15 Kasım, kullanıcı: "önceki gibi olacak, lakin BİR TANE düşecek; kaliteli olsun; düşecek, bitecek"):
//   ESKİ GİRİŞ SAHNESİNİN AYNISI: aynı kamera (40°, karşıdan, hafif yukarıdan), aynı ışıklar (sıcak ana ışık + GERÇEK GÖLGE,
//   arkadan/yandan renkli kenar ışıkları), aynı opak zemin. Fark: 36 koli yerine TEK Yüküm kolisi (ortadan YÜKÜM bandı).
//   Koli ekranın en üstünden fizikle düşer: havada döner, zemine çarpar, seker, devrilip oturur → sonra resme döner, 3B kapanır.
// HER SEFERİNDE AYNI: fizik, kare sürelerine göre her çalıştırmada milimetrik farklı sonuç verir. Bu yüzden düşüş BİR KEZ fizikle
//   KAYDEDİLDİ (Design/LoginFall.json, saniyede 30 kare: konum + dönüş). Her açılışta fizik ÇALIŞMAZ, kayıt oynatılır → birebir aynı.
//   Yeniden kayıt (koli ölçüsü/başlangıcı değişirse): simülatörde "-recordFall" argümanıyla aç → Documents/LoginFall.json → Design/'a kopyala.
//   Kayıt bulunamazsa: kısa, sabit bir düşüş animasyonu oynar (uygulama yine açılır).
// İNİŞ NOKTASI: kayıtta koli zeminde ~(0, 0,1)'e dik oturur, YÜKÜM bandı görünür → ekranın ~%80-%88'i: formun altındaki boşluk.

// ⮕ KULLANIM [LoginBoxDrop]: kullanır: LoginView › body (ZStack'in en arkasında, tam ekran)
struct LoginBoxDrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var rig = LoginBoxRig()

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        StillScene(startDelay: .milliseconds(250)) { root, scene, finish in
            rig.build(root: root, scene: scene, palette: palette, finish: finish)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false) // [SWIFT] süs: dokunuş almaz, dokunuşlar forma gider
        .accessibilityHidden(true)
    }
}

// BU SINIF: sahneyi kurar; kaydı oynatır (ya da -recordFall ile fizikle kaydeder).
// ⮕ KULLANIM [LoginBoxRig]: kullanır: LoginBoxDrop › rig
@MainActor
final class LoginBoxRig {
    static let size: SIMD3<Float> = [0.9, 0.6, 0.7]   // koli ölçüsü (m): eski kolilerin büyükleri kadar
    static let dropAt: SIMD3<Float> = [0, 7.6, 0.8]   // bırakma noktası: ekranın üst kenarının üstü, iniş z = 0,8
    static let recordMode = ProcessInfo.processInfo.arguments.contains("-recordFall")

    // Kayıt: kareler [x, y, z, qx, qy, qz, qw] | nonisolated: arka planda okunabilsin
    nonisolated struct Recording: Codable, Sendable { var fps: Float; var frames: [[Float]] }

    private var subscription: Cancellable?   // kare aboneliği (oynatma/kayıt bitince kapanır)
    private var time: Float = 0
    private var frames: [[Float]] = []       // kayıt kipi
    private var stillFrames = 0
    private var last: SIMD3<Float> = .zero

    func build(root: Entity, scene: RealityKit.Scene, palette: Palette, finish: @escaping @MainActor () -> Void) {
        // ZEMİN (eski sahnenin aynısı): opak, mat → kolinin gerçek gölgesi buna düşer
        var floorMaterial = PhysicallyBasedMaterial()
        floorMaterial.baseColor = .init(tint: palette.floor)
        floorMaterial.roughness = 1.0
        floorMaterial.specular = .init(floatLiteral: 0.0)
        let floor = ModelEntity(mesh: .generateBox(width: 60, height: 0.02, depth: 60), materials: [floorMaterial])
        floor.position.y = -0.01
        root.addChild(floor)

        // IŞIKLAR (eski sahnenin aynısı)
        let key = Entity()
        key.components.set(DirectionalLightComponent(color: palette.keyLight, intensity: palette.keyIntensity))
        key.components.set(DirectionalLightComponent.Shadow(maximumDistance: 30, depthBias: 2)) // [SWIFT] gerçek gölge
        key.look(at: [0, 1.5, 0], from: [3, 9, 8], relativeTo: nil)
        root.addChild(key)
        for (from, color) in [(SIMD3<Float>(-6, 5, -3), palette.rimA), (SIMD3<Float>(6, 6, -3), palette.rimB), (SIMD3<Float>(-6, 1.5, 5), palette.rimB)] {
            let rim = Entity()
            rim.components.set(SpotLightComponent(color: color, intensity: palette.rimIntensity,
                                                  innerAngleInDegrees: 50, outerAngleInDegrees: 80, attenuationRadius: 30))
            rim.look(at: [0, 1.5, 0], from: from, relativeTo: nil)
            root.addChild(rim)
        }

        // KAMERA (eski sahnenin aynısı): karşıdan, hafif yukarıdan, dikey 40°
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 40
        camera.look(at: [0, 2.9, 0], from: [0, 3.6, 10.5], relativeTo: nil)
        root.addChild(camera)

        Task { @MainActor in
            let kit = await CardboardBoxKit.prepared(palette: palette)    // ⮕ önbellekli (dorselerle ortak)
            let box = kit.makeBox(size: Self.size).clone(recursive: true) // kalıbın KOPYASI
            await self.brand(box, palette: palette)
            box.position = Self.dropAt
            box.orientation = simd_quatf(angle: 0.9, axis: simd_normalize([0.6, 0.3, 0.8])) // havada eğik başlar
            root.addChild(box)

            if Self.recordMode { self.record(box, root: root, scene: scene, finish: finish); return }
            if let recording = await Self.loadRecording() { self.play(recording, box: box, scene: scene, finish: finish); return }
            await self.fallback(box, root: root, finish: finish) // kayıt yoksa
        }
    }

    // OYNATMA: her karede kayıttaki iki kare arası yumuşak geçiş (konum: doğrusal, dönüş: küresel) | fizik YOK
    private func play(_ recording: Recording, box: Entity, scene: RealityKit.Scene, finish: @escaping @MainActor () -> Void) {
        subscription = scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            guard let self else { return }
            self.time += Float(event.deltaTime)
            let x = self.time * recording.fps
            let k = min(Int(x), recording.frames.count - 1), k2 = min(k + 1, recording.frames.count - 1)
            let w = min(max(x - Float(k), 0), 1)
            let a = recording.frames[k], b = recording.frames[k2]
            box.transform = Transform(rotation: simd_slerp(simd_quatf(ix: a[3], iy: a[4], iz: a[5], r: a[6]), simd_quatf(ix: b[3], iy: b[4], iz: b[5], r: b[6]), w),
                                      translation: simd_mix(SIMD3(a[0], a[1], a[2]), SIMD3(b[0], b[1], b[2]), SIMD3(repeating: w)))
            if k >= recording.frames.count - 1 { // bitti → abonelik kapanır, sahne resme döner
                self.subscription?.cancel(); self.subscription = nil
                finish()
            }
        }
    }

    // KAYIT (yalnız geliştirici, "-recordFall"): gerçek fizikle düşür, saniyede 30 kare yaz, durunca Documents/LoginFall.json
    private func record(_ box: Entity, root: Entity, scene: RealityKit.Scene, finish: @escaping @MainActor () -> Void) {
        let ground = Entity() // görünmez fizik zemini (üst yüzü y = 0)
        ground.position = [0, -0.5, 0]
        ground.components.set(CollisionComponent(shapes: [.generateBox(size: [30, 1, 30])]))
        ground.components.set(PhysicsBodyComponent(massProperties: .default, material: .generate(friction: 0.8, restitution: 0.05), mode: .static))
        root.addChild(ground)
        box.components.set(CollisionComponent(shapes: [.generateBox(size: Self.size)]))
        var body = PhysicsBodyComponent(massProperties: .default, material: .generate(friction: 0.7, restitution: 0.12), mode: .dynamic)
        body.angularDamping = 0.5; body.linearDamping = 0.05
        box.components.set(body)
        // Kayıt ayarı (yalnız geliştirici): "-recAV x,y,z" açısal hız, "-recTilt açı" başlangıç eğikliği, "-recYaw açı" başlangıç yönü
        //   → kolinin dik ve YÜKÜM bandı kameraya bakarak oturduğu düşüş seçilip kaydedilir
        let args = UserDefaults.standard
        let av = (args.string(forKey: "recAV") ?? "-0.3,0.4,0.2").split(separator: ",").compactMap { Float($0) }
        let tilt = Float(args.string(forKey: "recTilt") ?? "0.4") ?? 0.4, yaw = Float(args.string(forKey: "recYaw") ?? "-0.2") ?? -0.2
        box.orientation = simd_quatf(angle: tilt, axis: simd_normalize([0.7, 0.1, 0.5])) * simd_quatf(angle: yaw, axis: [0, 1, 0])
        box.position.x = Float(args.string(forKey: "recX") ?? "") ?? -0.5 // bırakma yeri: fizik koliyi ~0,55 m sağa taşıyor → ortada otursun
        box.position.z = Float(args.string(forKey: "recZ") ?? "") ?? 1.5  // bırakma derinliği → iniş z ≈ 0,1 (formun altındaki boşluk)
        box.components.set(PhysicsMotionComponent(linearVelocity: [0, -3.5, 0], angularVelocity: av.count == 3 ? SIMD3(av[0], av[1], av[2]) : [0.4, 0.5, -0.3])) // düşerken döner
        subscription = scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            guard let self else { return }
            self.time += Float(event.deltaTime)
            while self.time >= Float(self.frames.count) / 30 {
                let t = box.transform
                self.frames.append([t.translation.x, t.translation.y, t.translation.z, t.rotation.imag.x, t.rotation.imag.y, t.rotation.imag.z, t.rotation.real].map { ($0 * 10000).rounded() / 10000 })
            }
            let now = box.position
            self.stillFrames = simd_distance(now, self.last) < 0.0005 && self.time > 1 ? self.stillFrames + 1 : 0
            self.last = now
            if self.stillFrames >= 30 || self.time > 7 {
                self.subscription?.cancel(); self.subscription = nil
                if let data = try? JSONEncoder().encode(Recording(fps: 30, frames: self.frames)),
                   let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    try? data.write(to: dir.appendingPathComponent("LoginFall.json"))
                }
                finish()
            }
        }
    }

    // Kayıt uygulama paketinden ARKA PLANDA okunur (ana iş parçacığı beklemez)
    private static func loadRecording() async -> Recording? {
        guard let url = Bundle.main.url(forResource: "LoginFall", withExtension: "json") else { return nil }
        return await Task.detached(priority: .userInitiated) { () -> Recording? in
            guard let data = try? Data(contentsOf: url), let r = try? JSONDecoder().decode(Recording.self, from: data), !r.frames.isEmpty else { return nil }
            return r
        }.value
    }

    // Kayıt yoksa: düz bir düşüş (sabit süreli)
    private func fallback(_ box: Entity, root: Entity, finish: @escaping @MainActor () -> Void) async {
        let rest = Transform(rotation: simd_quatf(angle: -0.3, axis: [0, 1, 0]), translation: [0, Self.size.y / 2, Self.dropAt.z])
        box.move(to: rest, relativeTo: root, duration: 0.8, timingFunction: .easeIn)
        try? await Task.sleep(for: .seconds(1.0))
        finish()
    }

    // BU FONKSİYON: koliye Yüküm markasını ekler: ortadan dört yüzü dolanan "YÜKÜM" bandı (simgedeki kutunun aynısı).
    // NEDEN ayrı ince yüzeyler (dokuyu bandın kendisine vermek yerine): kalıp önbellekte, dorselerle ortak; markayı yalnız bu kopyaya eklemek
    //   kalıbı değiştirmez. Yüzeyler bandın 1,5 mm üstünde → bantla titreşmez.
    private func brand(_ box: Entity, palette: Palette) async {
        let s = Self.size
        // 15 Kasım (son hali): simgedeki kutuyla BİREBİR aynı → kapak bandı DÜZ (kolinin kendi bandı), YÜKÜM yalnız ortadan dolanan bantta,
        //   her yüzde ORTALANMIŞ TEK yazı (tekrarlı ve basık kapak yazıları kaldırıldı: simgede yok, okunmuyordu).
        func bandMaterial(widthOverHeight ratio: Float) async -> PhysicallyBasedMaterial? {
            guard let tex = await CardboardArt.textureAsync(from: Self.bandImage(palette: palette, ratio: CGFloat(ratio))) else { return nil }
            var m = PhysicallyBasedMaterial()
            m.baseColor = .init(tint: .white, texture: .init(tex))
            m.roughness = 0.35
            return m
        }
        // ORTA BANT (15 Kasım, kullanıcı: "simgedeki kutunun 3 boyutlusu olsun"): kolinin ortasından dört yüzü dolanan YÜKÜM bandı
        //   — uygulama simgesi ve dönen logodaki kutuyla aynı tasarım (kapak bandı + orta marka bandı). Etiket kaldırıldı (simgede yok).
        let bandH = s.y * 0.30, bandY = s.y / 2 - s.y * 0.52 - bandH / 2 // simgedeki oranlar: üstten %52'de başlar, boyu %30
        guard let wide = await bandMaterial(widthOverHeight: s.x * 0.97 / bandH),   // ön/arka yüz
              let narrow = await bandMaterial(widthOverHeight: s.z * 0.97 / bandH) else { return } // yan yüzler
        for (width, material, position, yaw) in [
            (s.x * 0.97, wide, SIMD3<Float>(0, bandY, s.z / 2 + 0.003), Float(0)),             // ön
            (s.x * 0.97, wide, SIMD3<Float>(0, bandY, -s.z / 2 - 0.003), Float.pi),            // arka
            (s.z * 0.97, narrow, SIMD3<Float>(s.x / 2 + 0.003, bandY, 0), Float.pi / 2),      // sağ
            (s.z * 0.97, narrow, SIMD3<Float>(-s.x / 2 - 0.003, bandY, 0), -Float.pi / 2)     // sol
        ] {
            // 0,97: köşeler yuvarlak → bant yüzün kenarından taşmasın
            let band = ModelEntity(mesh: .generatePlane(width: width, height: bandH), materials: [material])
            band.position = position
            band.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            box.addChild(band)
        }
    }

    // Bant dokusu: koli bandı rengi + ORTADA tek "YÜKÜM" (simgedeki gibi: kalın, yuvarlak hatlı, koyu kahve; bandın ~%70'i yükseklikte)
    //   ratio: bandın en/boy oranı → yazı her yüzde gerilmeden, doğru oranda çıkar
    private static func bandImage(palette: Palette, ratio: CGFloat) -> UIImage {
        let size = CGSize(width: (240 * ratio).rounded(), height: 240)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            palette.tape.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            let base = UIFont.systemFont(ofSize: 170, weight: .black)
            let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 170) } ?? base // simgedeki yuvarlak yazı
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(red: 0.36, green: 0.21, blue: 0.09, alpha: 1)]
            let word = "YÜKÜM" as NSString
            let w = word.size(withAttributes: attrs)
            word.draw(at: CGPoint(x: (size.width - w.width) / 2, y: (size.height - w.height) / 2), withAttributes: attrs)
        }
    }
}
