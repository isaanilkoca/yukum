//
//  00_Rehber_Views.swift — Views/ — EKRANLAR (MVVM'in V'si)
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: SwiftUI ekranları. Yalnız çizer ve düğmeyi ViewModel'e bağlar. Ağ/servis/oturum çağrısı YOK (denetlendi).
//
// YAZIM KURALLARI
//  struct XView: View { @State private var viewModel = XViewModel() }  → ekran yenilense de aynı ViewModel yaşar
//  Görünüm parçaları Design/'dan (FormCard, LabeledInput, AccentButtonLabel, .themedScreen…); renk Palette'ten
//  Sayfa (sheet) adları …Sheet (CancelRequestSheet, ReportSheet, VehicleFormSheet)
//  İşlem sonrası animasyon: .actionFeedback($feedback) — Yük Veren koli (.seal/.unseal), Taşımacı kamyon (.track/.unload)
//  Arayüz testi kimlikleri: .accessibilityIdentifier("login.email" …) — metin değişse de testler (YukumUITests) kırılmaz
//
// AKIŞ HARİTASI (ekran → açtığı ekranlar)
//  LoginView ─┬─ RoleSelectionView (TEK kayıt ekranı, rol seçici) ─┬─ RegisterView (Yük Veren alanları)
//             │                                                    └─ CarrierRegisterView (Taşımacı alanları)
//             ├─ VerifyEmailView (kayıttan sonra / doğrulanmamış girişte, sheet)
//             ├─ ForgotPasswordView (sheet)
//             └─ HomeView (tam ekran; rol göre iki görünüm)
//  HomeView ─┬─ YÜK VEREN: "Yeni ilan ver" → CreateListingView · ilan kartı → ListingOffersView
//            ├─ TAŞIMACI: ilan kartı → ListingDetailView · filtre → OpenListingsFilterView · Sırala menüsü · filtre kapsülleri
//            ├─ zil → NotificationsView
//            └─ sol üst fotoğraf → ProfileView
//  ProfileView ─┬─ YÜK VEREN: Devam Eden İşler / Eski Teklifler → OldOffersView(scope) · İlanlarım → MyListingsView
//               ├─ TAŞIMACI: Devam Eden İşler / Tekliflerim / Geçmiş → MyOffersView(scope) · Araçlarım → VehiclesView
//               │            Beğendiklerim → FavoritesView
//               ├─ ORTAK: Hesap Bilgilerim → AccountInfoView · Engellediklerim → BlockedUsersView
//               └─ ALT: Gizlilik → PrivacyView · Kullanım Koşulları → TermsView · Hesabı Sil → DeleteAccountView · Çıkış
//  ListingOffersView → CarrierProfileView, ChatView, CreateListingView (düzenle)
//  ListingDetailView → ShipperProfileView, VehiclesView (araç yoksa "Araç ekle")
//  MyOffersView → ChatView, CancelRequestSheet          OldOffersView → ChatView, CarrierProfileView, RatingView, CancelRequestSheet
//  ChatView → RatingView (Yük Veren işi bitirince)
//
// DOSYA → VIEWMODEL → NOT
//  LoginView               LoginViewModel            3B tek koli (Design/LoginBoxDrop), tema düğmesi, Şifremi unuttum, Kayıt ol
//  RoleSelectionView       Register / CarrierRegister kayıt bitince rolün animasyonu → giriş ekranı + kod ekranı
//  RegisterView            RegisterViewModel         FormConsent ×2 (KVKK + Kullanım Koşulları)
//  CarrierRegisterView     CarrierRegisterViewModel  aynı, Taşımacı
//  VerifyEmailView         VerifyEmailViewModel      .oneTimeCode (Mail'den otomatik kod), 60 sn geri sayım (TimelineView)
//  ForgotPasswordView      ForgotPasswordViewModel   2 adım
//  HomeView                HomeViewModel             selamlama, liste, sonsuz kaydırma, rozetler, push izni
//  OpenListingsFilterView  HomeViewModel             il/ilçe, varış, bütçe, araç, tarih, "araçlarıma uygun", uzaklık, ağırlık
//  CreateListingView       CreateListingViewModel    3 kart: rota · yük · tarih/bütçe
//  ListingRow              —                         RouteCard / RouteDash: ilan kartı (iki rol ortak)
//  ListingDetailView       ListingDetail + Safety    teklif formu (tutar, araç, teslim tarihi), kalp, ⋯ (şikâyet/engelle)
//  ListingOffersView       ListingOffersViewModel    gelen teklifler + sıralama, kabul/ret, sayaç kartları, ilanı kaldır
//  MyListingsView          MyListingsViewModel       tüm ilanlar, durum rozetiyle
//  MyOffersView            MyOffersViewModel         scope: .pending / .active / .history; aşama düğmesi, iptal talebi kartı
//  OldOffersView           OldOffers + MyOffers      Yük Veren tarafı; puanla
//  CancelRequestSheet      —                         neden kapsülleri (FlowChips) + not + ilanı yeniden yayınla; CancelRequestCard
//  ChatView                Chat + Safety             balonlar, ⋯ (temizle, işi bitir, şikâyet/engelle)
//  RatingView              RatingViewModel           1–5 yıldız + yorum
//  CarrierProfileView      CarrierProfile + Safety   puan, yorumlar, araçlar (plakasız), ⋯
//  ShipperProfileView      ShipperProfile + Safety   firma, il, üyelik, sayılar (iletişim gizli), ⋯
//  ProfileView             (HomeViewModel verisi)    profil sayfası (üç çizgi menü YOK, kullanıcı kararı)
//  AccountInfoView         AccountInfoViewModel      ad, telefon, il, hakkında, foto (PhotosPicker)
//  VehiclesView            VehiclesViewModel         PlateBadge, VehicleFormSheet
//  FavoritesView           FavoritesViewModel        beğenilen açık ilanlar
//  NotificationsView       NotificationsViewModel    sola kaydır → sil, tümünü okundu yap
//  SafetyViews             SafetyViewModel           SafetyMenuItems (⋯ içi) + .safetyFlow(…) (onaylar) + ReportSheet
//  BlockedUsersView        BlockedUsersViewModel     engeli kaldır
//  DeleteAccountView       AccountViewModel          şifre onayı
//  PrivacyView / TermsView —                         sabit metinler (KVKK / Kullanım Koşulları: sıfır tolerans, 24 saatte inceleme)
