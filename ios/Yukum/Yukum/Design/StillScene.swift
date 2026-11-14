//
//  StillScene.swift
//  Yukum
//
//  PERFORMANS (15 Kasım): 3B sahneyi bir kez oynatır, bitince RESME çevirir ve 3B motoru tamamen kapatır.
//

import SwiftUI    // [SWIFT] ekran çizim kütüphanesi
import RealityKit // [SWIFT] Apple'ın 3B motoru
import UIKit      // [SWIFT] UIImage, UIViewRepresentable'ın UIKit tarafı

// ┌─ BAĞLANTI HARİTASI: StillScene.swift ─────────────────────────────────────────
// │ GELEN     : Design/LoginBoxDrop (giriş: düşen tek Yüküm kolisi) — 15 Kasım'dan beri tek 3B sahne
// │ GİDEN     : RealityKit ARView (kamerasız, "nonAR" kipte)
// │ REHBER    : Design/00_Rehber_Design.swift
// └──────────────────────────────────────────────────────────────────────
//
// SORUN: RealityView animasyon BİTTİKTEN SONRA da saniyede 60 kez sahneyi yeniden çizer (hiçbir şey kıpırdamasa bile).
//   Üstünde kayan yarı şeffaf kartlar da her karede yeniden birleştirilir → işlemci/ekran kartı boşuna çalışır, telefon ısınır,
//   kaydırma takılır (iPhone 11'de 13-14 Kasım'da görülen ısınma ve kasmanın ana kaynağı).
// ÇÖZÜM: sahneler zaten "gelsin, olsun, dursun" (kullanıcı kararı). Durduktan sonra 3B çizmeye gerek yok:
//   1) sahne ARView'da oynar  2) sahne "bitti" der (finish)  3) ARView o anın fotoğrafını çeker (snapshot)
//   4) ARView ekrandan kaldırılır (3B motor, ışıklar, modeller bellekten çıkar) → yerine aynı boyutta duran bir Image gelir.
//   Kullanıcı farkı görmez: son kare ile fotoğraf birebir aynı. Sonrası: sıfır 3B maliyeti.
// NEDEN RealityView değil ARView: RealityView'ın fotoğraf çekme yolu yok; ARView.snapshot var. cameraMode .nonAR → telefon kamerası AÇILMAZ.
// NEDEN zemin saydam: arkadaki 2B katmanlar (renk geçişi, dağlar) görünsün; fotoğraf da saydamlığı korur (PNG gibi alfa kanallı).

// ⮕ KULLANIM [StillScene]: kullanır: LoginBoxDrop › body
struct StillScene: View {
    // build: sahneyi kurar | root: her şeyin ekleneceği ata | scene: kare aboneliği gerekiyorsa (giriş ekranındaki fizik) | finish: "sahne durdu" çağrısı
    typealias Builder = @MainActor (_ root: Entity, _ scene: RealityKit.Scene, _ finish: @escaping @MainActor () -> Void) -> Void
    let build: Builder
    // ERTELEME (15 Kasım, kullanıcı: "butonlar geç yükleniyor"): 3B kurulum (ARView + Metal + model + yükler) ana iş parçacığını
    //   birkaç yüz ms meşgul eder. Ekran açılır açılmaz kurulursa geçiş animasyonu takılır, düğmeler geç gelir.
    //   Önce arayüz çizilsin ve geçiş bitsin (≈0,35 sn), SONRA sahne kurulsun. Giriş ekranında daha kısa (ilk ekran, geçiş yok).
    var startDelay: Duration = .milliseconds(350)

    @State private var still: UIImage? // dolunca 3B kalkar, bu resim kalır | @State: ekran yenilense de resim yaşar (sahne yeniden oynamaz)

    var body: some View {
        // NEDEN Color.clear + overlay: ölçüyü YALNIZ Color.clear belirler (verilen alanı tam alır, fazlasını istemez).
        //   ARView ve resim kendi "doğal" ölçülerini (resim 1206 × 2622 piksel) öne sürüp üstteki ZStack'i ekrandan genişletemez.
        //   15 Kasım: bu olmadan giriş formu ekranın soluna taşıyordu.
        Color.clear.overlay {
            if let still {
                Image(uiImage: still).resizable() // [SWIFT] resmi çerçeveye tam yay (ARView ile aynı çerçeve → piksel piksel aynı yer)
            } else {
                StillSceneHost(build: build, startDelay: startDelay) { image in still = image }
            }
        }
    }
}

// BU GÖRÜNÜM: ARView'ı SwiftUI'a taşır | UIViewRepresentable [SWIFT]: UIKit görünümünü SwiftUI içinde kullanma köprüsü
// ⮕ KULLANIM [StillSceneHost]: kullanır: StillScene › body
private struct StillSceneHost: UIViewRepresentable {
    let build: StillScene.Builder
    let startDelay: Duration
    let onStill: (UIImage) -> Void

    // makeUIView [SWIFT]: görünüm İLK kez gerektiğinde 1 kez çalışır
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false) // [SWIFT] AR yok: sanal kamera, telefon kamerası kapalı
        view.environment.background = .color(.clear) // sahnenin zemini saydam
        view.backgroundColor = .clear
        // ÇÖZÜNÜRLÜK (15 Kasım, kullanıcı: "kalite kötü"): ekranın GERÇEK piksel yoğunluğunda çiz (iPhone'da 3×).
        //   Açıkça verilmezse ARView daha düşük ölçekte çizebiliyor → koli bulanık; fotoğraf da o çözünürlükte kalıyordu.
        view.contentScaleFactor = UIScreen.main.nativeScale // [SWIFT] 1 nokta = kaç piksel
        let anchor = AnchorEntity(world: .zero) // [SWIFT] ARView'da her şey bir "çapa"ya bağlanır
        view.scene.addAnchor(anchor)
        let root = Entity()
        anchor.addChild(root)

        let scene = view.scene
        Task { @MainActor [weak view] in
            try? await Task.sleep(for: startDelay) // arayüz ve geçiş önce (yukarıdaki ERTELEME notu)
            guard view != nil else { return }      // bu arada ekran kapandıysa hiç kurma
            build(root, scene) { [weak view] in // [weak view] [SWIFT]: görünüm bu arada kalktıysa tutup bellekte bekletme
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120)) // son hareketin ekrana çizilmesini bekle (snapshot o kareyi alsın)
                    view?.snapshot(saveToHDR: false) { image in // [SWIFT] ARView'ın o anki karesi
                        if let image { onStill(image) }
                    }
                }
            }
        }
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {} // sahne kendi kendine oynar; SwiftUI'dan güncelleme yok
}
