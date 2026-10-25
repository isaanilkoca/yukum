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
│  Yukum.Domain         tablo varlıkları (hiçbir şeye bağlı değil)
│                                                       │
│  Yukum.Infrastructure veritabanı işleri (EF Core)  ──────► SQL Server (Docker)
└─────────────────────────────────────────────────────┘
```

**Bağımlılık kuralı:** ok yönünde bilir, tersini bilmez. `Domain` kimseyi bilmez. `Application` yalnız `Domain`'i bilir.
`Infrastructure`, `Application`'ın arayüzlerini gerçekleştirir. `Api` her şeyi birbirine bağlar.
**Faydası:** iş kuralları SQL Server'ı bilmediği için veritabanı olmadan test edilebilir; veritabanı değişirse iş kuralları etkilenmez.

---

## 2. Klasörler ve projeler

| Yer | Ne işe yarar | Swift/iOS benzetmesi |
|---|---|---|
| `backend/Yukum.slnx` | Çözüm dosyası: tüm projeleri bir arada tutar | `.xcworkspace` |
| `backend/src/Yukum.Domain` | Tabloların C# karşılığı (`BaseEntity`, ileride `Load`, `Offer`...). Hiçbir pakete bağlı değil | Saf model `struct`'ları |
| `backend/src/Yukum.Application` | İş kuralları: handler'lar, `IRepository`, `IUnitOfWork` arayüzleri | ViewModel/Service katmanı + `protocol`'ler |
| `backend/src/Yukum.Infrastructure` | Veritabanı: `AppDbContext`, `Repository`, migration'lar | `APIClient`/kalıcılık katmanı |
| `backend/src/Yukum.Api` | HTTP kapısı: `Program.cs`, controller'lar, hata/JSON ayarları | Uygulamanın `@main` giriş noktası |
| `backend/tests/Yukum.UnitTests` | Veritabansız hızlı testler (sahte repo ile) | Swift Testing birim testleri |
| `backend/tests/Yukum.IntegrationTests` | Gerçek API + gerçek SQL Server'a karşı testler | XCUITest'e yakın uçtan uca |
| `docs/` | Raporlar, günlük, kararlar, bu rehber, veri kaynakları | — |
| `docs/veri/il-ilce.json` | Doğrulanmış 81 il / 973 ilçe verisi (seed kaynağı) | — |

---

## 3. Dosya haritası (şu an var olanlar)

### Yukum.Domain
- `Common/BaseEntity.cs` — Tüm tabloların ortak alanları: `Id`, `CreatedAt`, `UpdatedAt`, `IsDeleted`, `RowVersion`.
- `Common/ITimestamped.cs` — "Ne zaman oluştu / değişti" sözleşmesi. `BaseEntity` ve kullanıcı (`AppUser`) uygular; `AppDbContext` bu alanları otomatik doldurur.
- `Accounts/` — Kimlik tabloları: `UserType`, `RoleNames`, `VehicleType`, `ShipperProfile`, `CarrierProfile`, `CarrierServiceCity`, `Vehicle`, `RefreshToken` (yalnız hash'i saklanır, rotasyon zinciri için).
- `Geography/City.cs`, `Geography/District.cs` — 81 il ve 973 ilçe. Sabit referans verisi olduğu için `BaseEntity`'den **türemez**: Id'leri GUID değil, plaka kodu (il) ve sıra numarasıdır (K-013).

### Yukum.Application
- `Abstractions/Persistence/IRepository.cs` — "Kayıt getir / ekle / sil" sözleşmesi. İş kuralı kodu yalnız bunu bilir.
- `Abstractions/Persistence/IGeographyRepository.cs` — İl/ilçe okuma sözleşmesi (il listesi, il var mı, ilin ilçeleri). İl/ilçe GUID'li `BaseEntity` olmadığı için genel `IRepository` yerine bu özel depo kullanılır.
- `Common/NotFoundException.cs` — "İstenen kayıt yok" hatası. API bunu 404'e çevirir.
- `Common/ConflictException.cs` — "Çakışma" hatası (örn. e-posta kayıtlı). API bunu 409'a çevirir.
- `Abstractions/Identity/IAccountService.cs` — Hesap oluşturma sözleşmesi. İş kuralı kodu ASP.NET Identity'yi bilmez.
- `Accounts/` — Kayıt akışı: komutlar (`RegisterShipperCommand`, `RegisterCarrierCommand`), Türkçe doğrulama kuralları (`RegisterValidators`, FluentValidation), `PasswordPolicy` (şifre kuralının tek kaynağı), `PhoneNumberNormalizer` (her telefon yazılışı → `+905…`), handler'lar.
- `Geography/` — İl/ilçe sorguları: `GetCitiesHandler`, `GetDistrictsHandler` ve istemciye giden `CityDto` / `DistrictDto` (yalnız `id` ve `name`).
- `Abstractions/Persistence/IUnitOfWork.cs` — "Yaptığım değişiklikleri tek seferde kaydet" sözleşmesi.
- `Abstractions/Messaging/IHandlers.cs` — `ICommandHandler` (durumu değiştirir) ve `IQueryHandler` (sadece okur) sözleşmeleri.
- `DependencyInjection.cs` — Handler sınıflarını kendisi bulup kaydeder; aynı komut için iki handler varsa açılışta hata verir.

### Yukum.Infrastructure
- `Identity/AppUser.cs` — Giriş yapabilen kullanıcı (ASP.NET Core Identity'den türer): ad, tür, aktif/engelli, KVKK onay zamanı. Şifre hash'i, kilit sayacı Identity'den gelir.
- `Persistence/AppDbContext.cs` — Veritabanıyla konuşan merkez (Identity'li). Tarih damgası, yumuşak silme, RowVersion kurallarını **tek yerde** uygular.
- `Persistence/Seed/RoleSeed.cs` — Admin/Shipper/Carrier rollerinin sabit numaraları ve seed'i.
- `Persistence/Configurations/` — Her tablonun kuralları (sütun uzunluğu, benzersizlik, ilişki, seed) ayrı bir sınıfta: il/ilçe, `AppUser`, `Role`, iki profil, araç, çalışma bölgesi, `RefreshToken`. `AppDbContext` bunları tek satırla toplar.
- `Persistence/Seed/GeographySeed.cs` — `docs/veri/il-ilce.json`'dan il ve ilçeleri okur. JSON, derleme sırasında dll'in içine gömülür (`Yukum.Infrastructure.csproj`); çalışırken ayrı dosya aranmaz.
- `Persistence/GeographyRepository.cs` — `IGeographyRepository`'nin gerçeği; sonuçları `IMemoryCache`'te 24 saat saklar (boş sonuç saklanmaz).
- `Identity/AccountService.cs` — Hesabı tek işlemde kurar: kullanıcı + rol + profil + araçlar + çalışma illeri; çift e-posta/telefon → `ConflictException`.
- `Identity/PasswordPolicyValidator.cs` — Şifre kuralını Identity'ye bağlar (Identity'nin ASCII-yalnız harf kontrolü yerine).
- `Persistence/Repository.cs` — `IRepository`'nin EF Core ile gerçeği.
- `Persistence/UnitOfWork.cs` — `IUnitOfWork`'in gerçeği.
- `Persistence/Migrations/` — Veritabanı şemasının sürüm kaydı (aşağıda). Elle düzenlenmez, `dotnet ef` üretir.
- `DependencyInjection.cs` — Bağlantıyı, saat servisini ve repository'leri uygulamaya tanıtır.

### Yukum.Api
- `Program.cs` — Uygulamanın açılış planı: hangi servisler var, isteğin hangi sırayla işleneceği.
- `Controllers/AuthController.cs` — `POST /api/v1/auth/register/shipper` ve `/register/carrier` (anonim). İstemci sözleşmesi: `docs/api/Auth.md`.
- `Controllers/CitiesController.cs` — `GET /api/v1/cities` ve `GET /api/v1/cities/{cityId}/districts` (anonim, istemci tarafında 1 gün önbellek). İlk gerçek uçlar. İstemci sözleşmesi: `docs/api/Cities.md`.
- `Middleware/GlobalExceptionHandler.cs` — Yakalanmamış hatayı çevirir: `NotFoundException` → 404, `ConflictException` → 409, FluentValidation `ValidationException` → 400 (mesajlar gösterilir), diğer her şey → sade 500 (iç detay sızmaz).
- `Health/DatabaseHealthCheck.cs` — `GET /health`: veritabanı ayakta mı? (200 / 503)
- `Json/JsonSetup.cs` + `Json/UtcDateTimeConverters.cs` — JSON kuralları: camelCase, enum string, tarih UTC `…T10:15:00Z`.
- `Validation/ValidationProblemResponse.cs` — Geçersiz veri (400) cevabını hata formatına ve camelCase alan adlarına çevirir.
- `appsettings.json` — Ayarlar (loglama). **Gizli bilgi buraya yazılmaz.**

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
