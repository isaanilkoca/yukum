//
//  DesignPalette.swift
//  Yukum
//
//  Tasarımın tüm renkleri tek yerde. Tema değişecekse YALNIZ bu dosya değişir.
//

import SwiftUI    // [SWIFT] ekran çizim kütüphanesi
import UIKit      // [SWIFT] UIColor, UIImage ve resim çizici (UIGraphicsImageRenderer) buradan gelir

// ┌─ BAĞLANTI HARİTASI: DesignPalette.swift ─────────────────────────────────────────
// │ GELEN     : Design/BoxSceneBackground, BoxSceneRig (malzemeler), TapedBoxBackground | Views/LoginView
// │ GİDEN     : yok
// │ REHBER    : Design/00_Rehber_Design.swift (hangi teknik nerede, okuma sırası)
// └──────────────────────────────────────────────────────────────────────

// PALET MANTIĞI: her şey kolinin renginden (kraft karton) türetilir → arka plan koliyle kavga etmez.
//   GECE  "depo"  : çok koyu kahve (espresso) zemin; koliler sıcak amber ışıkla aydınlanır, ince soğuk-gri kenar ışığı koliyi zeminden ayırır.
//   GÜNDÜZ "karton": krem/keten zemin; aynı koliler yumuşak gün ışığında.
//   Vurgu (düğme): koli bandı turuncusu; iki modda aynı → marka rengi sabit kalır.
// NEDEN mor/mavi yok: kartonun karşıt rengi olduğu için göz yoruyordu; sıcak tonlar birbirini taşır.
// Color = SwiftUI rengi (2B katmanlar) | UIColor = RealityKit malzemeleri ve ışıkları bunu ister.
// ⮕ KULLANIM [Palette]: kullanır: SceneBackground, TapedBoxBackground, LoginView
struct Palette {
    let isDark: Bool

    // Arka plan (2B renk geçişi) ve arkadaki bulanık ışık haleleri
    var skyTop: Color { isDark ? Color(red: 0.065, green: 0.050, blue: 0.038) : Color(red: 0.975, green: 0.945, blue: 0.890) }
    var skyBottom: Color { isDark ? Color(red: 0.125, green: 0.090, blue: 0.060) : Color(red: 0.925, green: 0.860, blue: 0.750) }
    var glowA: Color { isDark ? Color(red: 1.0, green: 0.55, blue: 0.15).opacity(0.26) : Color(red: 1.0, green: 0.70, blue: 0.35).opacity(0.30) } // amber
    var glowB: Color { isDark ? Color(red: 0.80, green: 0.38, blue: 0.12).opacity(0.24) : Color(red: 1.0, green: 0.88, blue: 0.62).opacity(0.45) } // bakır / saman

    // Yazı ve düğme
    var title: Color { isDark ? Color(red: 0.98, green: 0.94, blue: 0.86) : Color(red: 0.24, green: 0.17, blue: 0.11) } // krem / koyu kahve
    var accent: Color { Color(red: 1.0, green: 0.58, blue: 0.05) }      // koli bandı turuncusu
    var buttonText: Color { Color(red: 0.10, green: 0.06, blue: 0.02) }

    // Form kartı (Design/FormStyle.swift): arka plandan NET ayrılsın diye opak
    var cardSurface: Color { isDark ? Color(red: 0.105, green: 0.085, blue: 0.068) : Color(red: 1.0, green: 0.985, blue: 0.960) }   // kart zemini
    var cardOpacity: Double { isDark ? 0.30 : 0.32 } // kart ne kadar opak: düşük → sahne daha çok görünür, yüksek → form daha net
    var cardBorder: Color { isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.04) }
    var fieldSurface: Color { isDark ? Color(red: 0.165, green: 0.135, blue: 0.108).opacity(0.82) : Color(red: 0.975, green: 0.955, blue: 0.920).opacity(0.86) } // giriş kutusu zemini (karttan bir ton farklı)
    var fieldBorder: Color { isDark ? Color.white.opacity(0.09) : Color.black.opacity(0.07) }
    var label: Color { isDark ? Color(red: 0.96, green: 0.92, blue: 0.85) : Color(red: 0.24, green: 0.17, blue: 0.11) }
    var labelShadow: Color { isDark ? Color.black.opacity(0.8) : Color.white.opacity(0.9) } // etiketin arkasındaki ince hale              // alan etiketi

    // 3B sahne: zemin ve ışıklar
    var floor: UIColor { isDark ? UIColor(red: 0.05, green: 0.038, blue: 0.028, alpha: 1) : UIColor(red: 0.90, green: 0.83, blue: 0.71, alpha: 1) }
    var floorOpacity: Float { isDark ? 0.74 : 0.90 } // zemin ne kadar opaksa yansıma o kadar silik
    var keyLight: UIColor { UIColor(red: 1.0, green: 0.94, blue: 0.85, alpha: 1) } // ana ışık: sıcak beyaz
    var keyIntensity: Float { isDark ? 5200 : 5600 }
    var rimA: UIColor { isDark ? UIColor(red: 1.0, green: 0.62, blue: 0.25, alpha: 1) : UIColor(red: 1.0, green: 0.80, blue: 0.55, alpha: 1) }  // kenar ışığı 1: amber
    var rimB: UIColor { isDark ? UIColor(red: 0.62, green: 0.70, blue: 0.82, alpha: 1) : UIColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1) } // kenar ışığı 2: gecede soğuk gri (koliyi zeminden ayırır)
    var rimIntensity: Float { isDark ? 110000 : 14000 }

    // Kamyon sahnesi (Design/TruckLoadView.swift)
    var cabPaint: UIColor { UIColor(red: 1.0, green: 0.55, blue: 0.02, alpha: 1) }  // kabin: koli bandı turuncusu (düğmeyle aynı aile)
    var cargoGlass: UIColor { isDark ? UIColor(red: 1.0, green: 0.93, blue: 0.82, alpha: 1) : UIColor(red: 0.55, green: 0.45, blue: 0.35, alpha: 1) } // şeffaf kasa camının rengi
    var cargoEdge: UIColor { isDark ? UIColor(red: 1.0, green: 0.86, blue: 0.62, alpha: 1) : UIColor(red: 0.45, green: 0.33, blue: 0.22, alpha: 1) }  // kasa kenar çizgileri
    var podium: UIColor { isDark ? UIColor(red: 0.10, green: 0.078, blue: 0.058, alpha: 1) : UIColor(red: 0.86, green: 0.78, blue: 0.66, alpha: 1) }  // aracın durduğu disk

    // Bantlar
    var tape: UIColor { UIColor(red: 0.90, green: 0.78, blue: 0.56, alpha: 1) } // kolinin üstündeki bant: açık bej, parlak
    var screenTape: Color { Color(red: 0.80, green: 0.62, blue: 0.36) }       // ekrana çekilen bant

    // Koli renkleri: yalnız GERÇEK kargo kolisi (kraft karton) tonları; hafif farklı tonlar yığına derinlik verir.
    var boxColors: [UIColor] {
        [
            UIColor(red: 0.76, green: 0.56, blue: 0.34, alpha: 1), // kraft
            UIColor(red: 0.70, green: 0.50, blue: 0.29, alpha: 1), // koyu kraft
            UIColor(red: 0.80, green: 0.61, blue: 0.39, alpha: 1), // açık kraft
            UIColor(red: 0.73, green: 0.53, blue: 0.31, alpha: 1)  // ara ton
        ]
    }
}
