//
//  PerfLog.swift
//  Yukum
//
//  GEÇİCİ ÖLÇÜM (13 Kasım): girişten ana ekrana kadar hangi aşama ne kadar sürüyor → Xcode konsoluna yazar.
//  Gecikme çözülünce çağrılarıyla birlikte silinecek (ara: "PerfLog.").
//

import Foundation // [SWIFT] temel araçlar (zaman ölçümü: ContinuousClock)

// ┌─ BAĞLANTI HARİTASI: PerfLog.swift ─────────────────────────────────────────
// │ GELEN     : ViewModels/LoginViewModel (login / restoreSession başı = sıfır noktası) | Views/HomeView (ekran göründü)
// │             Design/TruckLoadView (dokular, model, yükler) | Views/LoginView (giriş sahnesi kaldırıldı)
// │ GİDEN     : yok (yalnız print)
// └──────────────────────────────────────────────────────────────────────
//
// NASIL OKUNUR (Xcode konsolu, filtre: ⏱):
//   ⏱ [+1840 ms | Δ 1200 ms] model yüklendi
//      +  : sıfır noktasından (girişe basış) bu yana geçen süre
//      Δ  : bir önceki satırdan bu yana → en büyük Δ = darboğaz
// NEDEN yalnız DEBUG'da yazar: mağaza sürümünde konsol kirlenmesin; çağrılar yerinde kalsa da iş yapmaz.

// ⮕ KULLANIM [PerfLog]: kullanır: LoginViewModel, HomeView, LoginView, TruckLoadRig
@MainActor
enum PerfLog { // enum [SWIFT]: örneği üretilmeyen, yalnız static üyeleri olan kutu
    private static let clock = ContinuousClock() // [SWIFT] uyku/duraklamadan etkilenmeyen saat
    private static var start = clock.now
    private static var last = clock.now

    // Sıfır noktası: girişe basıldı ya da otomatik giriş başladı
    static func reset(_ label: String) {
        start = clock.now
        last = start
        #if DEBUG
        print("⏱ ──── \(label) ────")
        #endif
    }

    // Bir aşama bitti: sıfırdan ve öncekinden bu yana geçen süreyi yazar
    static func mark(_ label: String) {
        let now = clock.now
        #if DEBUG
        print("⏱ [+\(ms(now - start)) ms | Δ \(ms(now - last)) ms] \(label)")
        #endif
        last = now
    }

    private static func ms(_ d: Duration) -> Int { Int(d / .milliseconds(1)) } // Duration ÷ 1 ms = kaç milisaniye
}
