# iOS Çalışma Planı — Modelden Viewa (kısa yol)

Kural: **alttan üste** oku. Her adım bir öncekine yaslanır. Her dosyanın başındaki
`BAĞLANTI HARİTASI` kutusu "kim çağırır / kimi çağırır" der; `HAZIR (Swift/Apple)` = Apple'ın kodu,
`BİZİM` = bizim yazdığımız. Başlangıç haritası: `App/YukumApp.swift` (PROJE HARİTASI).

| # | Katman | Aç | Bağlantı | Kendine sor |
|---|--------|----|----------|-------------|
| 1 | **Model** (veri kalıbı) | `Models/Listings/Listing`, `CreateListingRequest`, `Models/Offers/*`, `Models/Auth/*`, `VehicleType` | Codable struct; JSON ↔ Swift | Request ile Response neden ayrı? `VehicleType` neden tek kaynak? |
| 2 | **Güvenlik** | `Security/KeychainStore`, `DeviceID` | AuthSession kullanır | Refresh token neden Keychain'de, erişim jetonu neden bellekte? |
| 3 | **Networking** | `HTTPMethod` → `APIConfig` → `APIError`/`APIErrorResponse` → `Error+UserMessage` → `AuthSession` → `APIClient` | Servisler yalnız `APIClient`'a konuşur | 401'de ne olur? Tek uçuş (single-flight) neden gerekli? |
| 4 | **Services** | `Services/Protocols/*Servicing` sonra `ListingService`, `OfferService`, `ChatService`, `CityService`, `AuthService` | Protokol = sözleşme; gerçek servis `extension X: Xing {}` ile bağlanır | Protokol neden var? (test için sahte servis) |
| 5 | **Konum** | `Location/LocationProviding`, `LocationManager` | HomeViewModel kullanır | Neden View konuma dokunmaz? |
| 6 | **ViewModel** | sırayla: `OldOffers` → `MyOffers` → `ListingOffers` → `ListingDetail` → `Chat`(+`ChatContext`) → `Home` → `Login` → `CreateListing` → `Register` → `CarrierRegister` | `@Observable`; servisleri init'te alır (DI) | Durum nerede, kural nerede? `load()` View'dan nasıl tetiklenir? |
| 7 | **View** | `ListingRow` → `OldOffersView` → `MyOffersView` → `ListingOffersView` → `ListingDetailView` → `ChatView` → `HomeView` → `LoginView` → `RoleSelection` → `Register`/`CarrierRegister` → `CreateListingView` | `@State private var viewModel` + `@Bindable` + `$viewModel.x` | View'da ağ/kural var mı? (olmamalı) |
| 8 | **Test** | `YukumTests/Support/Fake*` sonra `ViewModels/*Tests`, `Networking/AuthSessionTests` | Sahte servis → ViewModel → doğrula | Sahte servis neden simülatörsüz test sağlar? |

## Her dosyada tek döngü
1. Üst kutuyu oku (kim bağlı). 2. `⮕ ZİNCİR` yorumlarını izle. 3. `[SWIFT]` ile `[BİZİM]`i ayır. 4. Soruyu cevapla.

## Uçtan uca iz: "Teklif Ver"
`ListingDetailView` (Teklif Ver düğmesi) → `ListingDetailViewModel.submit()` → `OfferServicing.create` →
`OfferService` → `APIClient.send` (POST `/api/v1/listings/{id}/offers`) → backend → `CreateOfferRequest` / `OfferResponse` →
ViewModel durumu (`isSuccess`/`errorMessage`) → View yeniden çizilir.

Diğer izler: **Giriş** (`LoginView→LoginViewModel→AuthService→AuthSession→Keychain`),
**Yakınımdakiler** (`HomeView Toggle→nearMeChanged→LocationManager→reloadKey→load→openListings(lat,lon)`),
**Oturum bitti** (`APIClient 401→AuthSession refresh reddi→.sessionExpired→HomeView dismiss`).

## Bitti sayılır
Her adımın sorusunu kendi cümlenle cevaplayabiliyorsan. Mülakat özeti:
"View çizer, ViewModel karar verir, Service protokol arkasında konuşur, APIClient tek kapıdır, Model veridir; hepsi testte sahteyle değiştirilebilir."
