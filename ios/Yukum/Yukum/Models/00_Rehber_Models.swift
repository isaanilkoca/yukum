//
//  00_Rehber_Models.swift — MODELS (VERİ TARAFI) — bu klasörün altı
//  (Bu dosyada kod yok; klasörün ilk dosyası olarak ne nerede olduğunu anlatır.)
//

// MVVM'de 'Model' = verinin kendisi + veriye ulaşan her şey. Burada 4 iş var, her biri bir alt klasörde:
// 
// VERİ KALIPLARI (JSON'un Swift hâli, kod yok sadece alanlar):  Auth/  Listings/  Offers/  Chat/  Geography/  Vehicles/
// API'YE KONUŞAN SERVİSLER:   Services/   (her fonksiyon bir API ucu)
// SERVİSLERİN ORTAK KAPISI:   Networking/ (APIClient: gönder, jeton, hata çevirme)
// YARDIMCILAR:                Security/ (Keychain, cihaz kimliği)  ·  Location/ (telefonun konumu)
// 
//
//  Auth/        giriş-kayıt paketleri (LoginRequest, LoginResponse, LoginUser, RegisterRequest, RegisterResponse, RegisterCarrierRequest, VehicleRequest)
//  Listings/    ilan modelleri (Listing, CreateListingRequest, ListingResponse)
//  Offers/      teklif modelleri (CarrierOffer, ListingOffer, ShipperHistoryOffer, CreateOfferRequest, OfferResponse, UnseenCount)
//  Chat/        sohbet modelleri (ChatMessage, SendMessageRequest)
//  Geography/   City, District
//  Vehicles/    VehicleType (araç türleri, iki ekranda tek kaynak)
//  Services/    AuthService, ListingService, OfferService, ChatService, CityService + Protocols/ (sözleşmeler)
//  Networking/  APIClient, AuthSession, hata türleri
//  Security/    KeychainStore, DeviceID
//  Location/    LocationManager, LocationProviding
//
// Her alt klasörün kendi 00_Rehber_… dosyası var.
