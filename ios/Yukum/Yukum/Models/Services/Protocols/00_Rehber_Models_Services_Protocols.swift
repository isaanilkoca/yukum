//
//  00_Rehber_Models_Services_Protocols.swift — Protocols — servis sözleşmeleri
//  (Bu dosyada kod yok; klasörün ilk dosyası olarak ne nerede olduğunu anlatır.)
//

// Sözleşme = 'şu fonksiyonlar olmalı' listesi, içi boş. ViewModel somut servise değil bunlara bağlanır;
// gerçek uygulamada gerçek servis, testte (YukumTests/Support/Fake…) sahte servis takılır.
// 
//
//  AuthServicing     ← AuthService   (kullanan: Login/Register/CarrierRegister ViewModel)
//  ListingServicing  ← ListingService
//  OfferServicing    ← OfferService
//  ChatServicing     ← ChatService
//  CityServicing     ← CityService
//  SessionRestoring  ← AuthSession (Networking). İçinde 2 sözleşme: SessionRestoring (otomatik giriş: LoginViewModel) ve SessionSigningOut (çıkış: HomeViewModel)
