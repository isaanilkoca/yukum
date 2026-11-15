# Backend Rehberi — "Bu ne işe yarar?"

Bu dosya, backend'de kullandığımız her aracın, paketin, klasörün ve kavramın **ne işe yaradığını** anlatır.
Amaç: kodu sonradan açan (sen ya da başka biri) "bu neden var?" diye takılmasın.
Adım adım ne yaptığımız: `Ilerleme_Gunlugu.md`. Neden öyle karar verdik: `Karar_Kayitlari.md`.

> **Kodun içindeki açıklamalar:** C#'ta Swift'teki `///` karşılığı `/// <summary>` yorumudur.
> VS Code'da bir sınıfın/metodun üzerine gelince (hover) Xcode'daki Quick Help gibi görünür.
> Her sınıfın ve herkese açık metodun üstünde var. Yeni yazılan her kodda da olacak.

---

## 1. Büyük resim

```
iOS uygulaması (SwiftUI)
        │  HTTPS + JSON
        ▼
┌─────────────────────────────────────────────────────┐
│  Yukum.Api            kapı: adresler, JSON, hatalar   │
│     │                                                 │
│     ▼                                                 │
│  Yukum.Application    iş kuralları (handler'lar)      │
│     │                                                 │
│     ▼                                                 │
│  Yukum.Domain         tablo varlıkları (hiçbir şeye bağlı değil)   │
│                                                       │
│  Yukum.Infrastructure veritabanı işleri (EF Core)  ──────► SQL Server (Docker)
└─────────────────────────────────────────────────────┘
```

**Bağımlılık kuralı:** ok yönünde bilir, tersini bilmez. `Domain` kimseyi bilmez. `Application` yalnız `Domain`'i bilir.
`Infrastructure`, `Application`'ın arayüzlerini gerçekleştirir. `Api` her şeyi birbirine bağlar.
**Faydası:** iş kuralları SQL Server'ı bilmediği için veritabanı olmadan test edilebilir; veritabanı değişirse iş kuralları etkilenmez.

---

## 2. Klasörler ve projeler

```
backend/
├── Yukum.slnx                      çözüm dosyası (Xcode'daki .xcworkspace)
├── Dockerfile · dotnet-tools.json  API imajı · yerel araç (dotnet-ef)
├── src/
│   ├── Yukum.Domain/               tablo varlıkları — hiçbir pakete bağlı değil
│   │   ├── Common/                 BaseEntity, ITimestamped
│   │   ├── Accounts/               kullanıcıya bağlı tablolar (profil, araç, jeton, engel, şikâyet, doğrulama kodu)
│   │   ├── Geography/              City, District
│   │   ├── Listings/               ilan, teklif, mesaj, puan, favori, görüntülenme + durum enum'ları
│   │   └── Notifications/          Notification, DeviceToken, NotificationType
│   ├── Yukum.Application/          iş kuralları — yalnız Domain'i bilir
│   │   ├── Abstractions/           sözleşmeler (interface): Persistence/ Identity/ Messaging/ Notifications/
│   │   ├── Common/                 ortak hatalar (404/409/401/403/423), PagedResult, GeoMath
│   │   └── <Özellik>/              Accounts · Geography · Listings · Offers · Messages · Reviews · Engagement
│   │                               · Notifications · PriceReference · Vehicles   (her biri: Contracts + Handlers + Validator)
│   ├── Yukum.Infrastructure/       sözleşmelerin gerçeği — veritabanı, kimlik, e-posta, push
│   │   ├── Persistence/            AppDbContext, Repository, UnitOfWork, özel repolar
│   │   │   ├── Configurations/     tablo kuralları (sütun, indeks, ilişki)
│   │   │   ├── Migrations/         şema sürümleri (dotnet ef üretir, elle düzenlenmez) — 24 migration
│   │   │   └── Seed/               roller + 81 il / 973 ilçe
│   │   ├── Identity/               ASP.NET Identity, JWT, yenileme jetonu, hesap, doğrulama kodu, e-posta, profil fotoğrafı
│   │   └── Push/                   APNs (Apple push)
│   └── Yukum.Api/                  HTTP kapısı — her şeyi birbirine bağlar
│       ├── Program.cs              açılış planı (servisler, ara katmanlar, hız sınırı, Scalar)
│       ├── Controllers/            uçlar (aşağıda 3. bölüm)
│       ├── Background/             PushWorker (arka planda push gönderir)
│       ├── Middleware/             GlobalExceptionHandler (hata → Türkçe ProblemDetails)
│       ├── Json/ · Validation/ · Health/
│       └── appsettings*.json       ayarlar (GİZLİ BİLGİ YOK; gizliler user-secrets'ta)
└── tests/
    ├── Yukum.UnitTests/            veritabansız hızlı testler (NSubstitute ile sahte bağımlılık)
    └── Yukum.IntegrationTests/     gerçek API + gerçek SQL Server (Testcontainers: her test kendi veritabanını açar)
        ├── Api/                    uç uca HTTP testleri (yetki matrisi dahil)
        ├── Data/                   servis/repository testleri + dışa istek atan göndericiler (Resend, APNs)
        └── Support/                YukumApiFactory, SqlServerFixture, CapturingEmailSender…
```

**Yazım kuralları (backend)**

| Kural | Örnek |
|---|---|
| Komut (durumu değiştirir) `…Command` → `ICommandHandler<TCommand, TResult>` | `CreateOfferCommand` → `CreateOfferHandler` |
| Sorgu (yalnız okur) `…Query` → `IQueryHandler<TQuery, TResult>` | `GetOpenListingsQuery` → `GetOpenListingsHandler` |
| İstemciye giden `…Dto` (record), gelen gövde `…Request` | `ListingDto`, `ReportUserRequest` |
| Doğrulama `…Validator` (FluentValidation, Türkçe mesaj) | `CreateOfferValidator` |
| Sözleşme `I…` Application'da, gerçeği Infrastructure'da | `IBlockRepository` → `BlockRepository` |
| Handler'lar elle kaydedilmez: `AddHandlersFromAssembly` bulur | yeni handler = yeni sınıf, başka yere dokunma |
| Her sınıf/metotta Türkçe `/// <summary>`; karmaşık akışta `BAĞLANTI HARİTASI` / `ZİNCİR` yorumu | `SafetyContracts.cs` başı |
| DTO record'da `Guid/DateTime X = default` YAZMA → OpenAPI belgesi 500'e düşer | varsayılansız parametre |

---

## 3. Dosya haritası ve API uçları

### Yukum.Domain (tablolar)
- `Common/` — `BaseEntity` (Id, CreatedAt, UpdatedAt, IsDeleted = yumuşak silme, RowVersion = eşzamanlılık), `ITimestamped`.
- `Accounts/` — `ShipperProfile`, `CarrierProfile` (puan ortalaması, iş sayısı), `CarrierServiceCity`, `Vehicle` (plaka, marka, model, yıl), `VehicleType`,
  `RefreshToken` (yalnız hash), `UserType`, `RoleNames` (Admin/Shipper/Carrier), `UserBlock` + `UserReport` + `ReportReason` (engelle/şikâyet),
  `VerificationCode` + `VerificationPurpose` (e-posta doğrulama / şifre sıfırlama; kodun yalnız SHA-256 özeti).
- `Geography/` — `City` (Id = plaka), `District` (merkez koordinatı). `BaseEntity`'den türemez (K-013).
- `Listings/` — `Listing` + `ListingStatus` (Open → Assigned → Completed / Cancelled), `Offer` + `OfferStatus` + `JobStage` (iş aşaması, iptal talebi alanları),
  `Message`, `Review`, `FavoriteListing`, `ListingView` (kişi+gün tekil görüntülenme).
- `Notifications/` — `Notification` (uygulama içi + push kuyruğu), `DeviceToken` (telefonun APNs adresi), `NotificationType` (1–10).

### Yukum.Application (iş kuralları) — klasör → ne yapar
| Klasör | İçerik | Önemli kurallar |
|---|---|---|
| `Abstractions/Persistence` | `IRepository<T>`, `IUnitOfWork`, `IListingSearchRepository`, `IGeographyRepository`, `IEngagementRepository`, `IBlockRepository`, `INotificationRepository`, `IDeviceTokenRepository`, `IPriceReferenceRepository` | iş kodu EF Core'u bilmez |
| `Abstractions/Identity` | `IAuthService`, `IAccountService`, `ITokenService`, `IRefreshTokenService`, `IUserDirectory`, `ICarrierDirectory`, `IAvatarStorage`, `IVerificationService`, `IEmailSender` | iş kodu Identity'yi bilmez |
| `Abstractions/Messaging` | `ICommandHandler`, `IQueryHandler` | CQRS-lite (MediatR yok: ticari lisans) |
| `Abstractions/Notifications` | `IPushSender` (+ `PushMessage`, `PushResult`) | |
| `Accounts` | kayıt, giriş, yenileme/çıkış, hesap bilgileri + fotoğraf, hesap silme, **engelle/şikâyet** (`Safety*`), **doğrulama/şifre sıfırlama** (`Verification*`), `PasswordPolicy`, `PhoneNumberNormalizer` | KVKK + Kullanım Koşulları ayrı zorunlu; e-posta/telefon ROL başına benzersiz (K-022); silme = anonimleştirme (K-021) |
| `Geography` | il/ilçe sorguları | 24 saat önbellek |
| `Listings` | ilan oluştur/güncelle/kaldır, Taşımacı listesi (filtre, sıralama, sayfa, uzaklık), İlanlarım | kabul edilmiş ilan düzenlenemez/kaldırılamaz; engelli ilan sahibinin ilanı görünmez |
| `Offers` | teklif ver, kabul/ret, geri çek, aşama ilerlet, işi bitir, karşılıklı iptal, geçmişler | araçsız teklif yok; teklif bir araçla + tahmini teslim tarihiyle; engelde 409 |
| `Messages` | sohbet oku/yaz/temizle | yalnız teklifin iki tarafı; kapalı teklifte ve engelde yazma 409 |
| `Reviews` | puan ver, Taşımacı / Yük Veren profili | iş başına tek puan, yalnız Yük Veren |
| `Engagement` | favori, görüntülenme, ilan sayaçları | idempotent; sahibin bakışı sayılmaz |
| `Notifications` | bildirim listesi, okundu, sil, cihaz jetonu, `NotificationFactory` (metinler tek yerde), `PushDispatcher` | bildirim olayla AYNI işlemde yazılır (outbox, K-023/K-024) |
| `PriceReference` | emsal fiyat (aynı rota + araç, tamamlanmış işlerin medyanı) | yeterli veri yoksa boş |
| `Vehicles` | Araçlarım CRUD, `VehicleCompatibility` | büyük araç küçüğün işini yapar, frigorifik ayrı |
| `Common` | `NotFoundException` 404, `ConflictException` 409, `AuthExceptions` (401/403/423, `EmailNotVerifiedException` 403+code), `PagedResult`, `GeoMath` (kuş uçuşu km) | |

### Yukum.Infrastructure (gerçek uygulamalar)
- `Persistence/` — `AppDbContext` (tarih damgası, yumuşak silme, RowVersion tek yerde), `Repository<T>`, `UnitOfWork`, özel repolar:
  `ListingSearchRepository` (filtreler tek SQL'e; teklif verilmiş ve engelli ilanlar düşer), `EngagementRepository`, `BlockRepository` (kalıcı silme),
  `GeographyRepository` (IMemoryCache), `NotificationRepository`, `DeviceTokenRepository`, `PriceReferenceRepository`.
- `Persistence/Configurations/` — her tablonun kuralları (benzersiz indeksler: favori, görüntülenme, engel, teklif; filtreli indeksler).
- `Persistence/Seed/` — `RoleSeed`, `GeographySeed` (`docs/veri/il-ilce.json` dll'e gömülü).
- `Identity/` — `AppUser` (+ KvkkAcceptedAt, TermsAcceptedAt, EmailConfirmed), `AuthService` (şifre, 10 hatada 5 dk kilit, doğrulanmamış e-posta 403),
  `AccountService`, `JwtTokenService` + `JwtOptions` (HS256, 15 dk), `RefreshTokenService` (rotasyon; çalıntı jeton → aile iptal),
  `PasswordPolicyValidator`, `UserDirectory`, `CarrierDirectory`, `LocalAvatarStorage` (App_Data/avatars),
  `VerificationService` + `VerificationOptions` (kod: 6 hane, 15 dk, 5 deneme, 60 sn), `ResendEmailSender` + `EmailOptions`, `LogEmailSender` (geliştirme).
  Ayrıntı: `docs/Eposta_Sistemi.md`.
- `Push/` — `ApnsPushSender` (HTTP/2, sandbox/production), `ApnsJwtFactory` (ES256, 50 dk önbellek), `ApnsOptions`.
- `DependencyInjection.cs` — hepsini kaydeder; e-posta göndericisini ayara göre seçer (anahtar varsa Resend).

### Yukum.Api — controller → uçlar (hepsi `/api/v1` altında)
**Yetki:** (A) anonim · (G) giriş yapmış herkes · (Y) yalnız Yük Veren · (T) yalnız Taşımacı · (Y/T) iki rol

| Controller | Uçlar |
|---|---|
| `AuthController` (A, "auth" hız sınırı) | `POST auth/register/shipper` · `POST auth/register/carrier` · `POST auth/login` · `POST auth/refresh` · `POST auth/logout` · `POST auth/verify-email/send` · `POST auth/verify-email` · `POST auth/password/forgot` · `POST auth/password/reset` |
| `CitiesController` (A) | `GET cities` · `GET cities/{cityId}/districts` |
| `AccountController` (G) | `GET account/me` · `PUT account/me` · `POST account/avatar` · `DELETE account/avatar` · `POST account/delete` · `GET avatars/{id}` |
| `ListingsController` | `POST listings` (Y) · `GET listings/mine[?all=true]` (Y) · `PUT listings/{id}` (Y) · `POST listings/{id}/cancel` (Y) · `GET listings?filtre…` (T) |
| `EngagementController` | `PUT/DELETE listings/{id}/favorite` (T) · `GET listings/favorites` (T) · `POST listings/{id}/view` (T) · `GET listings/{id}/stats` (Y) |
| `OffersController` | `POST listings/{id}/offers` (T) · `GET listings/{id}/offers` (Y) · `POST offers/{id}/accept\|reject` (Y) · `GET offers/mine` (T) · `GET offers/mine/unseen-count` (T) · `POST offers/mine/seen` (T) · `GET offers/history` (Y) · `POST offers/{id}/withdraw` (T) · `POST offers/{id}/advance` (T) · `POST offers/{id}/complete` (Y/T) · `DELETE offers/{id}` (Y/T) · `POST offers/{id}/cancel-request` · `…/approve` · `…/reject` · `DELETE offers/{id}/cancel-request` (Y/T) |
| `MessagesController` (Y/T) | `GET` · `POST` · `DELETE offers/{offerId}/messages` |
| `ReviewsController` | `POST offers/{id}/review` (Y) · `GET carriers/{id}` (G) · `GET shippers/{id}` (G) |
| `VehiclesController` (T) | `GET vehicles` · `POST vehicles` · `PUT vehicles/{id}` · `DELETE vehicles/{id}` |
| `SafetyController` (G) | `PUT/DELETE users/{id}/block` · `GET account/blocks` · `POST users/{id}/report` |
| `NotificationsController` (G) | `GET notifications?page` · `GET notifications/unread-count` · `POST notifications/{id}/read` · `POST notifications/read-all` · `DELETE notifications/{id}` · `PUT notifications/device-token` · `DELETE notifications/device-token?deviceId=` |
| `PriceReferenceController` (G) | `GET price-reference?fromCityId&toCityId&vehicleType` |
| (Health) | `GET /health` — veritabanı ayakta mı (200/503) |

Canlı belge: API çalışırken `http://localhost:5054/scalar`. Yetki matrisi testi (`AuthorizationMatrixTests`) anonim olmaması gereken her ucu denetler.

**Diğer Api dosyaları:** `Background/PushWorker.cs` (bildirim kuyruğunu okur → APNs; geçersiz jetonu siler) · `Middleware/GlobalExceptionHandler.cs`
(400/401/403/404/409/423/500 → Türkçe ProblemDetails; `email_not_verified` için `code` alanı) · `Json/` (camelCase, enum yazı, UTC `…Z`) ·
`Validation/ValidationProblemResponse.cs` · `Health/DatabaseHealthCheck.cs`.

---

## 4. Kurduğumuz araçlar

| Araç | Ne işe yarar | Nerede kullanıyoruz |
|---|---|---|
| **.NET SDK 10** | C# kodunu derleyip çalıştıran araç takımı (`dotnet build/run/test`) | Backend'in tamamı |
| **VS Code + C# Dev Kit** | Kod editörü (Xcode'un backend karşılığı); hover'da `///` açıklamalarını gösterir | Backend kodunu okumak |
| **Docker Desktop** | Programları izole "kutularda" (konteyner) çalıştırır | SQL Server'ı Mac'te çalıştırmak, testlerde geçici veritabanı |
| **SQL Server 2025** (Docker'da) | İlişkisel veritabanı (MSSQL) — tüm veri burada | Konteyner adı `yukum-sql`, port 1433 |
| **dotnet-ef** | Migration üretir/uygular (`backend/dotnet-tools.json`, projeye özel) | Şema değişiklikleri |
| **Git + GitHub** | Sürüm kontrolü ve yedek | github.com/isaanilkoca/yukum |
| **Scalar** (pakete bağlı, kurulum yok) | API'yi tarayıcıda deneme sayfası; Postman yerine | `/scalar`, yalnız geliştirmede |

---

## 5. Paketler (NuGet) — Swift Package'ların karşılığı

| Paket | Nerede | Ne işe yarar |
|---|---|---|
| `Microsoft.AspNetCore.OpenApi` | Api | API'nin makine-okunur tarifini (OpenAPI/JSON) üretir. iOS sözleşmesinin tek kaynağı |
| `Scalar.AspNetCore` | Api | OpenAPI tarifinden okunaklı deneme sayfasını çizer |
| `Asp.Versioning.Mvc` (+`.ApiExplorer`, `.OpenApi`) | Api | `/api/v1/...` sürümlemesi; her sürüm için ayrı OpenAPI belgesi |
| `Serilog.AspNetCore` | Api | Yapısal loglama (konsol + günlük dosya), her satırda `traceId` |
| `Microsoft.EntityFrameworkCore.Design` | Api | `dotnet ef` aracının kodu okuması için (yalnız geliştirme zamanı) |
| `Microsoft.EntityFrameworkCore.SqlServer` | Infrastructure | EF Core'un SQL Server ile konuşması (ORM) |
| `System.Security.Cryptography.Pkcs` | Infrastructure | SQL kütüphanesinin dolaylı getirdiği paketin **güvenlik açığı olmayan** sürümünü sabitler |
| `FluentValidation` (+`.DependencyInjectionExtensions`) | Application | Doğrulama kuralları okunaklı yazılır, Türkçe mesajlar; alan adı ile hata eşlenir |
| `Microsoft.AspNetCore.Authentication.JwtBearer` | Api | Gelen istekteki `Authorization: Bearer` jetonunu doğrular (imza, süre, yayıncı, hedef) |
| `Microsoft.IdentityModel.JsonWebTokens` | Infrastructure | Erişim jetonunu (JWT) üretir ve imzalar |
| `Microsoft.AspNetCore.Identity.EntityFrameworkCore` | Infrastructure | Kullanıcı/rol tabloları, şifre hash'leme (PBKDF2), hesap kilidi |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | Application | Handler'ları kaydeden mekanizma için (DI arayüzleri) |
| `xunit` | Testler | Test çerçevesi (`[Fact]` = Swift Testing'deki `@Test`) |
| `Microsoft.AspNetCore.Mvc.Testing` | Integration | Gerçek API'yi bellekte ayağa kaldırıp testten çağırır |
| `Testcontainers.MsSql` | Integration | Testin kendi geçici SQL Server'ını Docker'da açıp kapatır |
| `Microsoft.Extensions.TimeProvider.Testing` | Integration | Testte saati sabitler (`FakeTimeProvider`) |
| `NSubstitute` | Unit | Sahte (mock) nesne üretir |

> **Neden MediatR / AutoMapper yok?** Ticari lisansa geçtiler (K-007). Handler kaydını kendimiz yazdık (`AddApplication`).

---

## 6. Bir isteğin yolculuğu

`GET /api/v1/...` isteği geldiğinde sırayla:

1. **Serilog**: isteğe bir `traceId` verir, tüm log satırlarına yazar.
2. **Hata yakalayıcı**: aşağıdaki herhangi bir adımda beklenmeyen hata çıkarsa devreye girer.
3. **Sürüm + yönlendirme**: `/api/v1/...` adresini ilgili controller'a bağlar.
4. **Doğrulama**: gelen veri geçersizse 400 + `errors` (alan adları camelCase).
5. **Controller**: işi ilgili **handler**'a verir (ileride; şu an gerçek controller yok).
6. **Handler** (Application): iş kuralını uygular, **Repository** ile veriyi okur/yazar, **UnitOfWork** ile tek seferde kaydeder.
7. **AppDbContext**: kaydederken tarih damgalarını yazar, silmeyi "işaretlemeye" çevirir.
8. **SQL Server**: veri kalıcı olur.
9. Cevap **JSON** olarak döner: camelCase alanlar, enum string, tarih UTC `…Z`.

Her hata cevabı aynı biçimdedir (ProblemDetails): `{ type, title, status, detail, errors, traceId }`.

---

## 7. Kavram sözlüğü

| Kavram | Anlamı |
|---|---|
| **ProblemDetails** | Hata cevaplarının standart JSON biçimi (RFC 9457). iOS tek bir `APIError` ile çözer |
| **traceId** | Her isteğin numarası. Kullanıcı "şu numaralı hatayı aldım" derse logda o isteği buluruz |
| **DTO** | API ile istemci arasında taşınan veri şekli. Tablo varlığı doğrudan dışarı verilmez |
| **DI (bağımlılık enjeksiyonu)** | Bir sınıfın ihtiyaç duyduğu parçaları (repo, saat) kendisi yaratmayıp dışarıdan alması. Testte sahtesi verilir |
| **Repository** | Veri erişimini saklayan ince katman ("kayıtları getir/ekle/sil") |
| **Unit of Work** | Birden çok değişikliği tek işlemde kaydeder: ya hepsi ya hiçbiri |
| **Handler / CQRS-lite** | Her kullanım senaryosu (ilan oluştur, teklif kabul et) ayrı bir sınıf. Komut değiştirir, sorgu okur |
| **EF Core** | C# nesneleri ile SQL tablolarını eşleyen ORM |
| **Migration** | Şema değişikliğinin sürümlü kaydı (`Persistence/Migrations`). Veritabanına elle SQL ile dokunulmaz |
| **Seed** | Başlangıç verisi (81 il, 973 ilçe) migration ile tabloya konur |
| **Yumuşak silme** | Kayıt silinmez, `IsDeleted=true` yapılır; normal sorgularda görünmez |
| **RowVersion** | İki kişi aynı kaydı aynı anda değiştirirse ikincisini yakalar (API'de 409). Çifte teklif kabulünü önler |
| **user-secrets** | Parolaları kodun dışında (kullanıcı klasöründe) tutan .NET özelliği. Git'e girmez |
| **Testcontainers** | Testin kendi geçici veritabanını Docker'da açıp bitince silmesi |
| **Health check** | `/health` adresi: uygulama + veritabanı sağlam mı? İzleme sistemleri yoklar |
| **IDOR** | Başkasının kaydına numarasını tahmin ederek erişme açığı. Rol kontrolüne ek olarak sahiplik kontrolüyle önlenir (ileride) |

---

## 8. Sık kullanılan komutlar

```bash
# API'yi çalıştır  →  http://localhost:5054/scalar   (durdurmak: Ctrl+C)
dotnet run --project backend/src/Yukum.Api --launch-profile http

# Tüm testler (veritabanı testleri için Docker açık olmalı)
dotnet test backend/Yukum.slnx

# Veritabanı şemasını uygula (backend/ klasöründe)
dotnet ef database update --project src/Yukum.Infrastructure --startup-project src/Yukum.Api

# Yeni migration üret (modeli değiştirdikten sonra; backend/ klasöründe)
dotnet ef migrations add AdiniVer --project src/Yukum.Infrastructure --startup-project src/Yukum.Api --output-dir Persistence/Migrations

# SQL Server konteyneri
docker ps                 # çalışıyor mu?
docker start yukum-sql    # kapalıysa başlat
```

**Bir şey "açılmıyor"sa** önce şunlara bak: API çalışıyor mu (terminal açık mı)? Docker Desktop açık mı? `yukum-sql` konteyneri çalışıyor mu?

---

## 9. Swift ↔ C# kısa karşılıklar

| Swift | C# |
|---|---|
| `protocol` | `interface` |
| `struct` (değer tipi, model) | `record` |
| `class` | `class` |
| `async/await`, `Task` | `async/await`, `Task` (aynı mantık) |
| `///` doküman yorumu | `/// <summary>` (XML doküman yorumu) |
| `Optional` (`String?`) | `Nullable` (`string?`) |
| `Codable` | `System.Text.Json` (otomatik) |
| `[weak self]` / ARC | Çöp toplayıcı (GC), `weak` gerekmez |
| `@Test` (Swift Testing) | `[Fact]` (xUnit) |
| SPM (Package.swift) | NuGet (`.csproj` içinde `PackageReference`) |
| `.xcconfig` / scheme | `appsettings.json` / ortam değişkeni / user-secrets |
