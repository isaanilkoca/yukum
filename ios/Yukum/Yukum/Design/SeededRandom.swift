//
//  SeededRandom.swift
//  Yukum
//
//  SABİT TOHUMLU rastgele sayı üreteci (15 Kasım, kullanıcı kararı: "her seferinde aynı kutular aynı yerlere düşsün, random olmasın").
//

import Foundation // [SWIFT] temel türler

// ┌─ BAĞLANTI HARİTASI: SeededRandom.swift ─────────────────────────────────────────
// │ GELEN     : BoxSceneRig (giriş yığını), TruckLoadView, TruckRoadView (dorse yükleri), CardboardBoxKit, CardboardArt, CargoKit (doku ve ayrıntılar)
// │ GİDEN     : yok
// │ REHBER    : Design/00_Rehber_Design.swift
// └──────────────────────────────────────────────────────────────────────
//
// NE: "rastgele görünen ama HER SEFERİNDE AYNI" sayılar. Aynı tohumla (seed) başlayan üreteç hep aynı sırayı verir.
// NEDEN: Swift'in .random(in:) her açılışta farklı sayı verir → yığın, yükler, dokular her açılışta değişiyordu.
//   Kullanıcı tutarlı bir marka görüntüsü istedi: giriş ekranı ve ana ekranlar her açılışta birebir aynı.
// NASIL KULLANILIR: Swift'in kendi fonksiyonlarına "using:" ile verilir, ayrı bir dil öğrenmek gerekmez:
//   var rng = SeededRandom(seed: 7)
//   Float.random(in: 0...1, using: &rng)   |   dizi.randomElement(using: &rng)!   |   Bool.random(using: &rng)
// ALGORİTMA: SplitMix64 (64 bitlik durum; her adımda sabit sayı eklenip karıştırılır). Hızlı, kısa, istatistiksel olarak yeterince düzgün.
// ⮕ KULLANIM [SeededRandom]: yukarıdaki GELEN dosyaları
struct SeededRandom: RandomNumberGenerator { // RandomNumberGenerator [SWIFT]: .random(in:using:) bu sözleşmeyi bekler
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    // Ölçüden tohum: aynı ölçüdeki koli/yük hep aynı görünür (etiket var mı, hangi karton tonu...) | bitPattern [SWIFT]: sayının ham bitleri
    init(_ size: SIMD3<Float>, salt: UInt64 = 0) {
        state = UInt64(size.x.bitPattern) &* 0x9E37_79B9 ^ UInt64(size.y.bitPattern) &* 0x85EB_CA6B ^ UInt64(size.z.bitPattern) &* 0xC2B2_AE35 ^ salt
    }

    // &+ &* [SWIFT]: taşmaya izin veren toplama/çarpma (taşma burada istenen şey: bitler karışır)
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
