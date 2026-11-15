//
//  00_Rehber_Models_Services_Protocols.swift — Models/Services/Protocols/ — SERVİS SÖZLEŞMELERİ
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: "Bu fonksiyonlara sahip olan her şey bu servis yerine geçebilir" sözleşmeleri.
// NEDEN: ViewModel somut servise değil protokole bağlı → testte sunucusuz sahte servis verilir (YukumTests/Support/Fake…).
//        Sektördeki adı: protokol tabanlı bağımlılık enjeksiyonu (DI).
//
// SÖZLEŞME → GERÇEK UYGULAMA → TESTTEKİ SAHTESİ
//  AuthServicing          → AuthService          → FakeAuthService
//  AccountServicing       → AccountService       → FakeAccountService
//  CityServicing          → CityService          → FakeCityService
//  ListingServicing       → ListingService       → FakeListingService
//  OfferServicing         → OfferService         → FakeOfferService
//  ChatServicing          → ChatService          → FakeChatService
//  ReviewServicing        → ReviewService        → FakeReviewService
//  NotificationServicing  → NotificationService  → FakeNotificationService
//  VehicleServicing       → VehicleService       → FakeVehicleService / TrackingVehicleService
//  SafetyServicing        → SafetyService        → FakeSafetyService
//  PushRegistering        → PushManager          → FakePush            (enable, unregister, setBadge)
//  SessionRestoring / SessionSigningOut → AuthSession → FakeSession   (restore, signOut)
//
// YAZIM KURALI: ad = …Servicing (servis) / …ing (yetenek). Yeni uç eklenince: önce protokole, sonra servise, sonra sahteye.
// KULLANIM: init(service: XServicing = XService()) — uygulama varsayılanı kullanır, test kendi sahtesini verir.
