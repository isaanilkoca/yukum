//
//  00_Rehber_Design.swift — DESIGN (TASARIM / ANİMASYON)
//  (Bu dosyada kod yok; klasörün ilk dosyası olarak ne nerede olduğunu ve HANGİ TEKNİKLE yapıldığını anlatır.)
//

// Bu klasör: uygulamanın görsel kimliği ve animasyonları. Veri, kural, API isteği YOK; ViewModel YOK.
// Views/ klasöründeki ekranlar buradaki parçaları arka plan / süs olarak kullanır.
//
// HİÇBİR ŞEY DIŞARIDAN ALINMADI: hazır model, resim dosyası, animasyon dosyası ya da ek kütüphane yok.
// Hepsi Apple'ın iOS içinde gelen üç aracıyla, kodla üretiliyor:
//
//   ARAÇ            NE İÇİN                                   BU PROJEDE NEREDE
//   SwiftUI         2B arayüz: yazı, düğme, renk geçişi,       ScreenTape (bantlar), TapedBoxBackground (sıra),
//                   maske, animasyon                           arka plandaki renk geçişi ve bulanık ışık haleleri
//   RealityKit      3B motor: şekil, malzeme, ışık, kamera,    BoxSceneBackground (sahne), BoxSceneRig (düşme/yığılma)
//                   FİZİK (yerçekimi, çarpışma)
//   Core Graphics   kodla resim çizme                          CardboardArt (karton dokusu, oklar, barkodlu etiket)
//
// DOSYA                   NE YAPAR
//
//  DesignPalette           tüm renkler (gece / gündüz). Tema değişecekse yalnız burası.
//  BoxSceneBackground      3B sahne: zemin, görünmez duvarlar, ışıklar, kamera. Bir ekranın arkasına konur.
//  BoxSceneRig             kalıp kolileri hazırlar, kopyalarını sırayla bırakır, yansımaları eşitler, "durdu" haberini verir, yığın durunca sahneyi dondurur.
//  CardboardArt            koli yüzeyindeki resimleri çizer (doku + baskı + etiket).
//  ScreenTape              ekranı geçen koli bandı (2B).
//  FormStyle               form görünümü: opak kart (FormCard) + etiketli giriş kutusu (LabeledInput). Hareketli arka planda formu net ayırır.
//  TapedBoxBackground      koli sahnesi + bantlar birlikte: ekranlar bunu arka plan olarak kullanır (Views/LoginView).
//
// ── KOLİ NASIL YAPILDI (RealityKit) ─────────────────────────────────────────────
//   1. ŞEKİL    : MeshResource.generateBox(size:cornerRadius:) → köşesi yuvarlatılmış kutu. Hazır fonksiyon; ölçüyü biz veririz.
//   2. MALZEME  : PhysicallyBasedMaterial → renk (tint) × doku (CardboardArt'ın çizdiği resim), pürüz (roughness), vernik (clearcoat).
//                 "Kaliteli" görüntü buradan gelir: yüzey ışığa gerçek karton gibi tepki verir.
//   3. AYRINTI  : bant, bandın sarkan uçları, kapak yarığı, kargo etiketi = koliye ÇOCUK olarak eklenmiş ince kutular.
//                 Çocuk oldukları için koliyle birlikte döner/düşer.
//   4. FİZİK    : CollisionComponent ("şeklim bu, çarpışırım") + PhysicsBodyComponent(mode: .dynamic) ("ağırlığım var, düşerim").
//                 Düşme, çarpma, yığılma, durma: hepsini motor hesaplar. Biz yalnız koliyi yukarıda bir noktaya bırakırız.
//   5. YANSIMA  : her kolinin fiziksiz bir kopyası, y ekseni ters çevrilmiş bir atanın içinde → zeminin altında baş aşağı durur.
//                 Zemin yarı saydam olduğu için "parlak zemindeki yansıma" gibi görünür. Her karede kopya = asıl.
//   6. IŞIK     : önden sıcak beyaz ana ışık (gölge de bundan), arkadan/yandan renkli spotlar (kenarlarda parlak çizgi).
//
// ── BANT NASIL YAPILDI (yalnız SwiftUI) ─────────────────────────────────────────
//   1. Bant = düz renk + üstten alta parlaklık gradyanı + tekrar eden "YÜKÜM" yazısı, hafif döndürülmüş (rotationEffect).
//   2. "Çekilme" = bant baştan beri tam boyda çizili; üstünde bir MASKE var. Maskenin genişliği 0 → tam boy animasyonla büyür.
//      (Ölçekleseydik yazı da ezilirdi; maske yazıyı bozmaz.)
//   3. Sıra = tapesPulled sayacı 0'dan 7'ye birer birer artar; her artışta bir şerit uzar ve telefon hafifçe titrer (sensoryFeedback).
//   4. Başlama anı = koliler yerleşince BoxSceneRig "durdu" der (onSettled) → TapedBoxBackground.wrapScreen sayacı başlatır.
//
// ── OKUMA SIRASI (ilk kez okuyacaksan) ──────────────────────────────────────────
//   DesignPalette → ScreenTape (en kolayı, yalnız SwiftUI) → TapedBoxBackground (parçalar nasıl üst üste biniyor) → Views/LoginView (ekran bunu nasıl kullanıyor)
//   → BoxSceneBackground.buildScene (sahne kurulumu, 1→5 numaralı adımlar) → BoxSceneRig.spawnBox (tek koli nasıl doğuyor)
//   → CardboardArt (doku çizimi; en ayrıntılısı, en sona bırak).
//
// ── DENEMEK İÇİN ────────────────────────────────────────────────────────────────
//   Uygulamayı çalıştır: giriş ekranı (Views/LoginView) bu arka planla açılır. Ya da TapedBoxBackground.swift'in sonundaki #Preview.
//   Oynanacak sayılar: BoxSceneRig'in başındaki sabitler (koli sayısı, bırakma aralığı), TapedBoxBackground.tapes (bant yeri/açısı), DesignPalette.
