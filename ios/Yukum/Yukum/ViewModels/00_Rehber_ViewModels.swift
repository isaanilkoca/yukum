//
//  00_Rehber_ViewModels.swift — VIEWMODELS (DURUM + KURAL)
//  (Bu dosyada kod yok; klasörün ilk dosyası olarak ne nerede olduğunu anlatır.)
//

// Ekranın değişkenleri ve kuralları (alan boş mu, tutar geçerli mi, yükleniyor mu, hata yazısı).
// API isteğini KENDİSİ atmaz: Models/Services/ içindeki servisi çağırır, gelen Model'i değişkene koyar; View o değişkeni okur.
// Servisleri 'sözleşme' (…Servicing) olarak alır; testte sahte servis takılır.
// 
//
//  LoginViewModel            LoginView için. AuthService.login → POST /auth/login | AuthSession.restore → POST /auth/refresh (otomatik giriş)
//  RegisterViewModel         RegisterView için. AuthService.register → POST /auth/register/shipper
//  CarrierRegisterViewModel  CarrierRegisterView için. AuthService.registerCarrier → POST /auth/register/carrier
//  HomeViewModel             HomeView için. ListingService.openListings / myListings (GET /listings…), CityService (il/ilçe), OfferService.unseenCount (rozet), konum (LocationProviding), çıkış (AuthSession)
//  ListingDetailViewModel    ListingDetailView için. Tutarı kontrol eder → OfferService.create → POST /listings/{id}/offers
//  CreateListingViewModel    CreateListingView için. Formu kontrol eder → ListingService.create → POST /listings (il/ilçe için CityService)
//  ListingOffersViewModel    ListingOffersView için. OfferService.listingOffers / decide (kabul-red), ListingService.cancel (ilanı kaldır)
//  MyOffersViewModel         MyOffersView için. OfferService.myOffers, markSeen, hide
//  OldOffersViewModel        OldOffersView için. OfferService.shipperHistory, hide
//  ChatViewModel             ChatView için. ChatService.messages / send / clear, OfferService.complete; mesajları belirli aralıkla yeniler
//  ChatContext               ViewModel değil, küçük kural kutusu: sohbeti kim yazabilir/bitirebilir (rol + teklif durumu). Teklif ekranlarındaki ViewModel'ler üretir, ChatViewModel kullanır
//
// Bağlandığı Views/ dosyası: aynı adın başındaki kelime (HomeViewModel ↔ HomeView).
// Hataları 'Models/Networking/Error+UserMessage' Türkçeye çevirir (error.userMessage).
