# iOS Klasör Rehberi — ne nerede

Kural: **önce özellik, sonra katman.** Bir özelliğin (giriş, ilan, teklif, sohbet) bütün dosyaları
aynı klasörde durur. Dosya adının sonu katmanı söyler: `...View` çizer, `...ViewModel` karar verir,
`...Service` API'ye konuşur, geri kalanlar (`Listing`, `LoginRequest`…) Model'dir.

```
ios/Yukum/Yukum/
├─ App/        uygulamanın girişi
├─ Features/   özellikler (kullanıcının gördüğü işler)
│   ├─ Auth/       giriş · kayıt
│   ├─ Listings/   ilanlar · ana sayfa · il/ilçe
│   ├─ Offers/     teklifler
│   └─ Chat/       sohbet
└─ Core/       her özelliğin ortak kullandığı altyapı
    ├─ Networking/  API ile konuşma
    ├─ Security/    güvenli saklama
    ├─ Location/    telefonun konumu
    └─ Shared/      ortak küçük tipler
```

## App/ — uygulamanın girişi
| Dosya | Ne yapar |
|---|---|
| `YukumApp` | Uygulama buradan başlar; ilk ekranı açar. Üstünde proje haritası var. |
| `ContentView` | İlk ekranı (LoginView) taşıyan kap. |

## Features/Auth — "Kim olduğunu söyle"
| Dosya | Ne yapar |
|---|---|
| `LoginView` + `LoginViewModel` | Giriş ekranı; ViewModel alan kontrolü ve otomatik girişi yapar. |
| `RoleSelectionView` | Yük Veren mi Taşımacı mı seçimi. |
| `RegisterView` + `RegisterViewModel` | Yük Veren kaydı. |
| `CarrierRegisterView` + `CarrierRegisterViewModel` | Taşımacı kaydı (araç bilgisiyle). |
| `AuthService` + `AuthServicing` | **API'ye giden yer:** login, register. `Servicing` = sözleşme (test için). |
| `LoginRequest/Response/User`, `RegisterRequest/Response`, `RegisterCarrierRequest`, `VehicleRequest` | Giden ve gelen JSON'un Swift hâli. |

## Features/Listings — "Yük ilanları"
| Dosya | Ne yapar |
|---|---|
| `HomeView` + `HomeViewModel` | Ana sayfa: iki role göre liste, il/ilçe filtresi, Yakınımdakiler, rozet, çıkış. |
| `ListingRow` | Listedeki tek ilan satırının çizimi. |
| `ListingDetailView` + `ListingDetailViewModel` | İlan detayı + teklif verme formu. |
| `CreateListingView` + `CreateListingViewModel` | Yük Verenin ilan açma formu. |
| `ListingService` + `ListingServicing` | **API:** ilanları çek, ilan aç, ilanı kaldır. |
| `CityService` + `CityServicing` | **API:** il ve ilçe listesi (filtre için). |
| `Listing`, `CreateListingRequest`, `ListingResponse`, `City`, `District` | Modeller. |

## Features/Offers — "Fiyat teklifleri"
| Dosya | Ne yapar |
|---|---|
| `MyOffersView` + `MyOffersViewModel` | Taşımacının verdiği teklifler (Bekleyen / Geçmiş), silme. |
| `ListingOffersView` + `ListingOffersViewModel` | Yük Verenin ilanına gelen teklifler; kabul/red, ilanı kaldır. |
| `OldOffersView` + `OldOffersViewModel` | Yük Verenin geçmiş teklifleri. |
| `OfferService` + `OfferServicing` | **API:** teklif ver, listele, kabul/red, bitir, geçmiş, sil, rozet. |
| `CarrierOffer`, `ListingOffer`, `ShipperHistoryOffer`, `CreateOfferRequest`, `OfferResponse`, `UnseenCount` | Modeller. |

## Features/Chat — "Teklif sohbeti"
| Dosya | Ne yapar |
|---|---|
| `ChatView` + `ChatViewModel` | Sohbet ekranı; mesajları yoklar, gönderir, temizler, işi bitirir. |
| `ChatContext` | Kim yazabilir / kim bitirebilir kuralı (rol + teklif durumuna göre). |
| `ChatService` + `ChatServicing` | **API:** mesajları çek, yaz, temizle. |
| `ChatMessage`, `SendMessageRequest` | Modeller. |

## Core/ — ortak altyapı
| Klasör / dosya | Ne yapar |
|---|---|
| `Networking/APIClient` | **Ağın tek kapısı.** Jeton ekler, gönderir, 401'de yeniler, cevabı Model'e çevirir. |
| `Networking/AuthSession` | Jetonları tutar, yeniler, çıkış yapar (kendisi `/auth/refresh` ve `/auth/logout` atar). |
| `Networking/APIConfig`, `HTTPMethod` | Sunucu adresi; GET/POST/DELETE. |
| `Networking/APIError`, `APIErrorResponse`, `Error+UserMessage` | Hatayı Türkçe yazıya çevirir. |
| `Networking/Notification+SessionExpired` | "Oturum bitti" duyurusu (HomeView girişe döner). |
| `Networking/SessionRestoring` | Oturum açma/kapama sözleşmeleri (ViewModel'in gördüğü yüz). |
| `Security/KeychainStore`, `DeviceID` | Yenileme jetonunu ve cihaz kimliğini güvenle saklar. |
| `Location/LocationManager`, `LocationProviding` | Konum izni ve konum; ViewModel yalnız sözleşmeyi görür. |
| `Shared/VehicleType` | Araç türleri; iki ekranda tek kaynak. |

## Testler (YukumTests/) — aynı yapı
`Features/<Özellik>/…ViewModelTests` (ViewModel kuralları) · `Core/` (oturum, araç türü) · `Support/` (sahte servisler: `Fake…`).

## Bir işin izini nasıl sürerim?
"Teklif ver": `Features/Listings/ListingDetailView` → `ListingDetailViewModel.submit()` → `Features/Offers/OfferService.create` → `Core/Networking/APIClient` → `POST /listings/{id}/offers`.
