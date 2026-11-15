//
//  00_Rehber_ViewModels.swift — ViewModels/ — EKRAN MANTIĞI (MVVM'in VM'si)
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: Her ekranın durumu (alanlar, yükleniyor, hata) ve kararları (kontrol, istek, sonuç). Görünüm YOK; ekran yalnız okur ve düğmeyi bağlar.
//
// YAZIM KURALLARI (hepsinde aynı)
//  @MainActor @Observable final class XViewModel         → değişken değişince onu okuyan ekran kendiliğinden yenilenir
//  init(service: XServicing = XService())                 → uygulamada gerçek servis, testte sahte (YukumTests/ViewModels)
//  var errorMessage: String? · var isLoading = false      → ekran kırmızı yazı / çark gösterir
//  catch { errorMessage = error.userMessage }             → sunucunun Türkçe mesajı; iptal edilen istek ekrana yazılmaz
//  Başarılı mı? → fonksiyon Bool döner                    → ekran buna göre animasyon (ActionFeedback) oynatır / kapanır
//  Basit kontroller (boş alan, 6 haneli kod) burada; ASIL kural sunucuda (istemciye güvenilmez)
//
// VIEWMODEL → KULLANDIĞI SERVİS(LER) → ANA FONKSİYONLAR → EKRANI
//  ── Giriş / kayıt / hesap ──
//  LoginViewModel            Auth, SessionRestoring       restoreSession (otomatik giriş), login, registered, verified          LoginView
//                            403 "email_not_verified" gelirse verifyTarget dolar → kod ekranı açılır
//  RegisterViewModel         Auth                          register (Yük Veren; KVKK + Kullanım Koşulları ayrı zorunlu)        RegisterView
//  CarrierRegisterViewModel  Auth                          register (Taşımacı; kayıtta araç yok)                               CarrierRegisterView
//  VerifyEmailViewModel      Auth                          verify (yalnız 6 rakam), resend (60 sn kilit), secondsLeft          VerifyEmailView
//  ForgotPasswordViewModel   Auth                          sendCode (1. adım) → reset (2. adım: kod + yeni şifre ×2)           ForgotPasswordView
//  AccountInfoViewModel      Account, City                 load, save (telefon değişince şifre ister), uploadAvatar/removeAvatar,
//                                                          prepareAvatar (512×512 JPEG), displayPhone ("0532 123 45 67")       AccountInfoView
//  AccountViewModel          Account, SessionSigningOut    deleteAccount (şifre onaylı; aktif işte sunucu 409)                 DeleteAccountView
//  ── Ana ekran ──
//  HomeViewModel             Listing, Offer, City, Account, Notification, Push, Location, Session
//                            load/loadMore (sayfalı liste), applyFilter, filterChips/removeChip/clearFilters, nearMeChanged,
//                            loadUnread (zil), loadActiveJobCount (Devam Eden İşler rozeti), loadMe, renameUser, enablePush, signOut
//                                                                                                       HomeView, OpenListingsFilterView, ProfileView
//  ── İlan ──
//  CreateListingViewModel    Listing, City                 loadCities, fromCityChanged/toCityChanged (il→ilçe), submit (yeni/düzenle)  CreateListingView
//  ListingDetailViewModel    Listing, Offer, Vehicle       recordView, loadReference (emsal), loadVehicles, toggleFavorite (iyimser), submit (teklif)
//                                                                                                       ListingDetailView (Taşımacı)
//  ListingOffersViewModel    Listing, Offer                load, sorted (7 ölçüt), decide (kabul/ret), loadStats, cancelListing, openChat
//                                                                                                       ListingOffersView (Yük Veren)
//  MyListingsViewModel       Listing                       load (tüm durumlar), badge (Yayında / Taşımacı atandı / Tamamlandı / Kaldırıldı)  MyListingsView
//  FavoritesViewModel        Listing                       load, remove                                                         FavoritesView
//  ── Teklif / iş ──
//  MyOffersViewModel         Offer                         load/loadAndMarkSeen, offers(in: .pending/.active/.history), saveAmount, withdraw,
//                                                          advance (aşama), requestCancel/approve/reject/withdrawCancel, hide, can… kuralları
//                                                                                                       MyOffersView (Taşımacı)
//  OldOffersViewModel        Offer                         load, stageTitle, requestCancel…, canRate, hide, openChat            OldOffersView (Yük Veren)
//  ChatContext (struct)      —                             forCarrier / forShipperPending / forShipperHistory: kim yazabilir/bitirebilir TEK yerde
//  ChatViewModel             Chat                          load, startPolling (birkaç sn'de bir), send, clear, complete         ChatView
//  RatingViewModel           Review                        submit (1–5 yıldız + yorum)                                          RatingView
//  ── Profil / güvenlik / bildirim ──
//  CarrierProfileViewModel   Review                        load (puan, yorumlar, araçlar)                                      CarrierProfileView
//  ShipperProfileViewModel   Review                        load · MemberSince.text ("Mart 2026")                                ShipperProfileView
//  VehiclesViewModel         Vehicle                       load, save (tür/plaka/marka/model/yıl kontrol), delete               VehiclesView
//  SafetyViewModel           Safety                        load (engelli mi), setBlocked, report                                SafetyViews (⋯ menüsü)
//  BlockedUsersViewModel     Safety                        load, unblock                                                        BlockedUsersView
//  NotificationsViewModel    Notification                  load/loadMore, markAllRead, delete                                   NotificationsView
//
// TESTLER: YukumTests/ViewModels/* (her ViewModel'in her fonksiyonu en az bir testte çağrılır — 15 Kasım denetimi)
