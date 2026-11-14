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
    // Giriş ekranı: her şey düştükten sonra yanan tepe spotu (Design/BoxSceneRig › revealSpotlight) | dorse tavan lambası gibi soğuğa yakın beyaz
    var spotColor: UIColor { UIColor(red: 1.0, green: 0.99, blue: 0.96, alpha: 1) }   // beyaz (çok hafif sıcak)
    var spotIntensity: Float { isDark ? 900_000 : 0 } // 14 Kasım: 900 bin → 2,4 milyon (kullanıcı: "spot düşmüyor") | 4 milyonda koliler beyaza çekiyordu | sonra 1,3 milyon → 900 bin: kullanıcı "daha loş, sahne efekti" | gündüz 0: spot yalnız koyu modda
    var beam: Color { Color(red: 1.0, green: 0.99, blue: 0.96) } // görünen huzme ve yer havuzu (BoxSceneBackground › SpotBeam): beyaz, parlak

    // Dorse sahnesi (Design/TruckLoadView.swift) | hazır modelin YALNIZ dorsesi (kabin gizli) | kullanıcı isteğiyle sahne daha PARLAK
    var trailerKeyIntensity: Float { isDark ? 8200 : 8600 }   // ana ışık: giriş sahnesinden (keyIntensity) ~%55 güçlü
    var trailerFillIntensity: Float { isDark ? 3000 : 3400 }  // sağ-önden dolgu ışığı: gölgeli yüzler kararmasın
    var cargoGlass: UIColor { isDark ? UIColor(red: 1.0, green: 0.93, blue: 0.82, alpha: 1) : UIColor(red: 0.55, green: 0.45, blue: 0.35, alpha: 1) } // şeffaf kasa camının rengi
    var cargoEdge: UIColor { isDark ? UIColor(red: 1.0, green: 0.88, blue: 0.66, alpha: 1) : UIColor(red: 0.45, green: 0.33, blue: 0.22, alpha: 1) }  // kasa kenar çizgileri

    // Yol + yükleme sahnesi (Design/TruckRoadView.swift, Taşımacı ana ekranı, 14 Kasım) | aynı sıcak aile: kum rengi arazi, kahve tepeler, sıcak asfalt
    //   GECE: koyu arazi, turuncu ufuk ışığı (uzaktaki şehir), yükleme alanının projektörü yanar. GÜNDÜZ: buğday tarlası rengi arazi, krem gökyüzü.
    var land: Color { isDark ? Color(red: 0.085, green: 0.065, blue: 0.048) : Color(red: 0.86, green: 0.77, blue: 0.60) }        // ufkun altı (2B), asfalt sonda buna karışır
    var landHaze: Color { isDark ? Color(red: 0.17, green: 0.11, blue: 0.065) : Color(red: 0.93, green: 0.86, blue: 0.72) }     // ufka yakın arazi: pus (daha açık)
    var hillFar: Color { isDark ? Color(red: 0.12, green: 0.085, blue: 0.060) : Color(red: 0.84, green: 0.72, blue: 0.56) }     // uzak sıradağ
    var hillNear: Color { isDark ? Color(red: 0.095, green: 0.070, blue: 0.050) : Color(red: 0.76, green: 0.62, blue: 0.45) }   // yakın tepeler
    var horizonGlow: Color { isDark ? Color(red: 1.0, green: 0.52, blue: 0.16).opacity(0.42) : Color(red: 1.0, green: 0.78, blue: 0.45).opacity(0.60) } // ufuktaki ışık: gece şehir, gündüz güneş
    var star: Color { Color(red: 1.0, green: 0.95, blue: 0.85) } // yalnız gece
    var asphalt: UIColor { isDark ? UIColor(red: 0.075, green: 0.068, blue: 0.060, alpha: 1) : UIColor(red: 0.40, green: 0.37, blue: 0.34, alpha: 1) }
    var concrete: UIColor { isDark ? UIColor(red: 0.20, green: 0.185, blue: 0.17, alpha: 1) : UIColor(red: 0.72, green: 0.69, blue: 0.64, alpha: 1) } // yükleme alanı zemini (asfalttan açık)
    var roadLine: UIColor { isDark ? UIColor(red: 0.82, green: 0.79, blue: 0.72, alpha: 1) : UIColor(red: 0.99, green: 0.98, blue: 0.94, alpha: 1) } // şerit çizgisi (ışıktan etkilenmez)
    var postWhite: UIColor { UIColor(red: 0.93, green: 0.92, blue: 0.89, alpha: 1) }   // yol kenarı dikmesi
    var reflector: UIColor { UIColor(red: 1.0, green: 0.52, blue: 0.04, alpha: 1) }    // dikme reflektörü + yükleme alanı çizgisi: marka turuncusu
    var floodlight: UIColor { UIColor(red: 1.0, green: 0.93, blue: 0.80, alpha: 1) }   // yükleme alanı projektörü
    var floodIntensity: Float { isDark ? 900_000 : 0 } // yalnız gece yanar (gündüz güneş yeter)

    // Yük çeşitleri (Design/CargoKit.swift): tarım ürünleri ve gıda | gerçek ürün renkleri, kartonla aynı sıcak aile
    var crateWood: UIColor { UIColor(red: 0.66, green: 0.47, blue: 0.27, alpha: 1) }   // meyve kasası tahtası
    var palletWood: UIColor { UIColor(red: 0.78, green: 0.62, blue: 0.40, alpha: 1) }  // palet tahtası (açık çam)
    var orange: UIColor { UIColor(red: 1.0, green: 0.50, blue: 0.04, alpha: 1) }       // portakal
    var lemon: UIColor { UIColor(red: 1.0, green: 0.88, blue: 0.08, alpha: 1) }        // limon: canlı sarı (14 Kasım: daha doygun)
    var tomato: UIColor { UIColor(red: 0.86, green: 0.12, blue: 0.06, alpha: 1) }      // domates
    var avocado: UIColor { UIColor(red: 0.22, green: 0.34, blue: 0.08, alpha: 1) }     // avokado: gerçek yeşil, mat kabuk (14 Kasım: koyu-siyahımsı tondan açıldı)
    // Zeytinyağı tenekesi (kullanıcının gösterdiği 10 L teneke görseli, 14 Kasım): sıcak parlak altın gövde, açık altın kenar, koyu yeşil yassı kapak + açık halka
    // NOT: metal yüzey rengini çevresinden yansıtır; sahnemiz koyu olduğu için tam metal (metallic 1) teneke KARA görünüyordu
    //   → renk açık tutuldu ve CargoKit'te metallic 0,55'e indirildi: görseldeki gibi altın okunur.
    var tinGold: UIColor { UIColor(red: 0.92, green: 0.75, blue: 0.30, alpha: 1) }
    var tinRim: UIColor { UIColor(red: 0.98, green: 0.88, blue: 0.56, alpha: 1) }
    var capGreen: UIColor { UIColor(red: 0.05, green: 0.33, blue: 0.17, alpha: 1) }
    var spoutWhite: UIColor { UIColor(red: 0.95, green: 0.95, blue: 0.92, alpha: 1) }
    var sack: UIColor { UIColor(red: 0.80, green: 0.70, blue: 0.50, alpha: 1) }        // çuval (çuval bezi)
    var sackPrint: UIColor { UIColor(red: 0.62, green: 0.22, blue: 0.12, alpha: 1) }   // çuvalın üstündeki baskı bandı
    // Zeytinyağı şişesi (kullanıcının görselindeki cam şişe): şeffaf cam + içinde altın sarısı yağ + mantar tıpa
    var glassTint: UIColor { UIColor(red: 0.90, green: 0.96, blue: 0.88, alpha: 1) }   // camın çok hafif yeşilimsi rengi
    var oil: UIColor { UIColor(red: 0.88, green: 0.70, blue: 0.10, alpha: 1) }         // zeytinyağı: altın sarısı
    var cork: UIColor { UIColor(red: 0.74, green: 0.56, blue: 0.36, alpha: 1) }        // şişe mantarı
    // Meyve ayrıntıları: yaprak, çanak (domates), sap
    var leaf: UIColor { UIColor(red: 0.16, green: 0.44, blue: 0.12, alpha: 1) }
    var stem: UIColor { UIColor(red: 0.36, green: 0.26, blue: 0.12, alpha: 1) }

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
