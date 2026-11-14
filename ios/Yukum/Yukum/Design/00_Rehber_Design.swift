//
//  00_Rehber_Design.swift — DESIGN (TASARIM / ANİMASYON)
//  (Bu dosyada kod yok; klasörün ilk dosyası olarak ne nerede olduğunu ve HANGİ TEKNİKLE yapıldığını anlatır.)
//

// Bu klasör: uygulamanın görsel kimliği ve animasyonları. Veri, kural, API isteği YOK; ViewModel YOK.
// Views/ klasöründeki ekranlar buradaki parçaları arka plan / süs olarak kullanır.
//
// HİÇBİR ŞEY DIŞARIDAN ALINMADI: hazır model, resim dosyası, animasyon dosyası ya da ek kütüphane yok.
//   TEK İSTİSNA: Design/Truck.usdz — hazır 3B tır modeli ("Truck" by ROY, Sketchfab, CC-BY 4.0). Lisans atıf ister → Views/PrivacyView › Atıflar (silinmez).
//   Kullanan: TruckLoadView ve TruckRoadView (ikisinde de yalnız dorse).
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
//  TruckLoadView           Yük Veren ana ekranı: hazır modelin yalnız dorsesi, şeffaf kasaya yükler dizilir (+ TruckModel: modeli bir kez yükler).
//  TruckRoadView           Taşımacı ana ekranı: dorse yoldan yükleme alanına geri geri yanaşır, yerdeki yığın arka kapıdan içeri alınır; bir kez oynar, durur. Ufuk 2B Canvas, sahne 3B.
//  ActionFeedback          işlem sonrası tek seferlik animasyon: Yük Veren → koli kapanır + bantlanır | Taşımacı → lastik izi. + ScreenBackground (ikincil ekran zemini).
//  StillScene              PERFORMANS: 3B sahne bir kez oynar, bitince RESME döner ve 3B motor kapanır (ARView + snapshot). Üç sahne de bunu kullanır.
//  SeededRandom            sabit tohumlu "rastgele": yığın, yükler ve dokular her açılışta birebir aynı (kullanıcı kararı 15 Kasım).
//  FormStyle (alt kısım)   ikincil ekran parçaları: themedCard / themedRow / themedScreen, ChipButtonStyle, StatusBadge, EmptyStateCard, RouteLine.
//
// ── KOLİ NASIL YAPILDI (RealityKit) ─────────────────────────────────────────────
//   1. ŞEKİL    : MeshResource.generateBox(size:cornerRadius:) → köşesi yuvarlatılmış kutu. Hazır fonksiyon; ölçüyü biz veririz.
//   2. MALZEME  : PhysicallyBasedMaterial → renk (tint) × doku (CardboardArt'ın çizdiği resim), pürüz (roughness), vernik (clearcoat).
//                 (15 Kasım: parlak vernik/clearcoat katmanı performans için kaldırıldı.)
//                 "Kaliteli" görüntü buradan gelir: yüzey ışığa gerçek karton gibi tepki verir.
//   3. AYRINTI  : bant, bandın sarkan uçları, kapak yarığı, kargo etiketi = koliye ÇOCUK olarak eklenmiş ince kutular.
//                 Çocuk oldukları için koliyle birlikte döner/düşer.
//   4. FİZİK    : CollisionComponent + PhysicsBodyComponent(mode: .dynamic): düşme, çarpma, yığılma motor tarafından (dağınık görünüm).
//                 15 Kasım: bırakma noktaları sabit tohumlu ve hep yığının EN ALÇAK yerinin üstünden (BoxSceneRig.lowestSpot) → kule olmaz.
//                 KAYIT: fizik bir kez çalıştırılıp kaydedildi (Design/BoxFall.json, 30 kare/sn). Uygulama her açılışta bu kaydı OYNATIR,
//                 fizik çalışmaz → düşüş her seferinde birebir aynı. Yeniden kayıt: simülatörde "-recordFall" argümanı (BoxSceneRig başındaki not).
//   5. YANSIMA  : (15 Kasım'da kaldırıldı, performans) zemin artık opak, ters kopya yok.
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
