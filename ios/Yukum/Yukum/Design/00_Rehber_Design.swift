//
//  00_Rehber_Design.swift — Design/ — GÖRÜNÜM PARÇALARI (tasarım sistemi)
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: Uygulamanın görsel dili. Veri/iş mantığı YOK; ekranlar (Views/) bu parçaları birleştirir.
// KURAL: Renk ekranda elle yazılmaz → Palette(isDark:). Yeni ortak bileşen önce buraya, sonra ekrana.
//
// DOSYALAR
//  DesignPalette.swift    Palette: açık/koyu tema renkleri (title, label, accent = koli bandı turuncusu, danger, cardSurface…). Tek renk kaynağı.
//  ThemeToggle.swift      AppTheme (Sistem/Açık/Koyu, UserDefaults'ta) + ThemeToggle düğmesi (giriş ekranı sağ üst).
//  FormStyle.swift        Ortak form/liste parçaları:
//                           FormCard · LabeledInput (etiketli + simgeli kutu) · FormMessage (kırmızı hata / yeşil bilgi)
//                           FormConsent (onay kutusu; document: .kvkk → PrivacyView, .terms → TermsView)
//                           AccentButtonLabel (turuncu ana düğme + yükleniyor çarkı) · ChipButtonStyle · StatusBadge
//                           EmptyStateCard · LoadingCard · RouteLine
//                           .themedCard() .themedRow() .themedScreen() .busyIndicator(Bool)  ("İşleniyor…" katmanı)
//  ActionFeedback.swift   İşlem sonrası 2B animasyonlar (hep aynı oynar, bitince "then" çalışır):
//                           Yük Veren: .seal (koli bantlanır = olumlu) · .unseal (bant kesilir + İPTAL damgası = olumsuz)
//                           Taşımacı:  .track (lastik izi = olumlu)    · .unload (kamyondan koli iner = olumsuz)
//                           Kullanım: @State var feedback: ActionFeedback? → .actionFeedback($feedback) → feedback = ActionFeedback(.seal, "Mesaj") { sonra }
//                         + ScreenBackground (ekran zemini) · SoftGlow (bulanıklıksız hafif hale)
//  AvatarView.swift       Profil fotoğrafı (GET /api/v1/avatars/{id}, jetonlu), yoksa baş harfler. AvatarCache: aynı foto tekrar inmez.
//  YukumLogo.swift        YukumLogo (konum işareti + koli) · BrandTitle (logolu başlık) · PinShape.
//  LoginBoxDrop.swift     Giriş ekranındaki tek 3B koli: fizik BİR KEZ kaydedildi (LoginFall.json), her açılış kaydı oynatır (piksel piksel aynı).
//  StillScene.swift       3B sahneyi (RealityKit) bir kez oynatır, bitince RESME çevirip 3B'yi kapatır (pil/ısı).
//  CardboardArt.swift     Koli yüzey dokuları (karton, YÜKÜM bandı), önbellekli.
//  CardboardBoxKit.swift  3B koli modeli üretimi.
//  SeededRandom.swift     Sabit tohumlu rastgele (her açılış aynı) + TemplateCache. GENERİC YAPMA: Swift 6.3 Release derlemesi çöküyor.
//
// ZİNCİR: Views/* → FormStyle · ActionFeedback · Palette | LoginView → LoginBoxDrop → StillScene
