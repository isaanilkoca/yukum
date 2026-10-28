# Kod Anlatımı: projeyi nasıl okursun?

Bu belge, backend kodunu **hiç bilmeyen** birinin (sen) baştan sona izleyebilmesi için yazıldı. Kodun kendisi de satır satır Türkçe açıklamalıdır; bu belge o açıklamaların **haritasıdır**: hangi dosyayı hangi sırayla, hangi satırdan başlayarak okuyacağını söyler.

> **Satır numaraları** `409e739` sürümüne göredir. Kod değiştikçe birkaç satır kayabilir; dosya adı + yorum satırı yine bulur. VS Code'da: `Cmd+P` ile dosya adı yaz, `Cmd+Shift+O` ile dosyadaki metoda atla, bir ismin üzerinde `F12` = "tanıma git", `Shift+F12` = "nerede kullanılıyor".

İlgili belgeler: [`SQL_Rehberi.md`](SQL_Rehberi.md) (veritabanı), [`Backend_Rehberi.md`](Backend_Rehberi.md) (dosya/paket sözlüğü), [`api/`](api/) (iOS sözleşmeleri).

---

## 1. Büyük resim: 4 katman

Backend, bir soğan gibi katmanlıdır. **Ok yönü = "bilir"**; içteki dıştakini bilmez.

```
        ┌────────────────────────────────────────────────────────────┐
        │  Yukum.Api            "Kapı": adresler, JSON, hata cevapları │  ← iOS buraya konuşur
        └──────────────┬─────────────────────────────────────────────┘
                       │ bilir
        ┌──────────────▼─────────────────────────────────────────────┐
        │  Yukum.Application    "Beyin": iş kuralları, doğrulama      │
        │                       (arayüzleri tanımlar, gerçeğini bilmez)│
        └──────────────▲─────────────────────────────────────────────┘
                       │ bilir          ┌────────────────────────────┐
        ┌──────────────┴──────────────┐ │ Yukum.Infrastructure       │
        │  Yukum.Domain  "Sözlük":    │◄┤ "Eller": veritabanı,       │
        │  tabloların C# sınıfları,   │ │ Identity, JWT. Application │
        │  hiçbir pakete bağlı değil  │ │ arayüzlerini GERÇEKLEŞTİRİR│
        └─────────────────────────────┘ └────────────────────────────┘
```

| Katman | Ne yapar | Swift/iOS dünyasında karşılığı |
|---|---|---|
| **Domain** | Tabloların sınıfları (`City`, `Vehicle`...) ve temel kavramlar | Saf model `struct`'ları |
| **Application** | "Giriş yapılırsa ne olur?" gibi iş kuralları; `IRepository` gibi **arayüzler** | ViewModel / servis katmanı + `protocol`'ler |
| **Infrastructure** | Arayüzlerin gerçeği: SQL Server, Identity, JWT | `URLSession`/Keychain/CoreData gibi altyapı |
| **Api** | HTTP kapısı, JSON, hata formatı | Uygulamanın `@main` giriş noktası + ağ sınırı |

**Neden böyle?** Bir kuralı (örn. şifre politikası) değiştirmek için veritabanı koduna dokunmayasın; veritabanını değiştirirsen iş kuralları bozulmasın; testlerde gerçek veritabanı yerine sahtesini verebilesin.

### Hangi dosyayı hangi sırayla okumalı? (ilk gün için 12 dosya)

| # | Dosya | Neden |
|---|---|---|
| 1 | `Yukum.Domain/Geography/City.cs:7` | En basit sınıf: bir tablo = bir C# sınıfı |
| 2 | `Yukum.Domain/Common/BaseEntity.cs:8` | Tüm tabloların ortak alanları (`Id`, `CreatedAt`, `IsDeleted`...) |
| 3 | `Yukum.Application/Abstractions/Messaging/IHandlers.cs:10` | Bir "iş" nasıl tanımlanır (komut/sorgu + handler) |
| 4 | `Yukum.Application/Geography/GetDistrictsHandler.cs:8` | Gerçek bir iş kuralı: 15 satır |
| 5 | `Yukum.Api/Controllers/CitiesController.cs:24` | HTTP adresi nasıl bir handler'a bağlanır |
| 6 | `Yukum.Infrastructure/Persistence/GeographyRepository.cs:13` | Veritabanından okuma + önbellek |
| 7 | `Yukum.Infrastructure/Persistence/AppDbContext.cs:22` | Veritabanıyla konuşan merkez; otomatik zaman damgası, yumuşak silme |
| 8 | `Yukum.Api/Program.cs:22` | Her şeyin birbirine bağlandığı yer |
| 9 | `Yukum.Api/Middleware/GlobalExceptionHandler.cs:22` | Hata → HTTP cevabı eşlemesi |
| 10 | `Yukum.Application/Accounts/RegisterValidators.cs:13` | Türkçe doğrulama kuralları |
| 11 | `Yukum.Infrastructure/Identity/AccountService.cs:16` | Kayıt: kullanıcı + rol + profil tek işlemde |
| 12 | `Yukum.Infrastructure/Identity/AuthService.cs:14` | Giriş güvenliği: kilit, zamanlama, genel hata |

---

## 2. Yolculuk 1: `GET /api/v1/cities/42/districts` (Konya'nın ilçeleri)

En basit istek. Bir isteğin baştan sona izlediği yol:

| Adım | Ne oluyor | Nerede |
|---|---|---|
| 1 | iOS (ya da tarayıcı) isteği gönderir: `GET http://localhost:5054/api/v1/cities/42/districts`. Giriş (jeton) **gerekmez**. | |
| 2 | İstek, Program.cs'teki **istek hattından** (middleware) geçer: izleme numarası atanır, log yazılır, hata yakalayıcı hazır beklenir. | `Yukum.Api/Program.cs:128` |
| 3 | `MapControllers`, adresi bir controller metoduna bağlar. | `Yukum.Api/Program.cs:146` |
| 4 | Adres kalıbı eşleşir: `{cityId:int}` → `cityId = 42`. `abc` yazılsaydı eşleşmez, 404 olurdu. | `Yukum.Api/Controllers/CitiesController.cs:43` |
| 5 | Controller **iş yapmaz**, handler'a devreder. | `Yukum.Api/Controllers/CitiesController.cs:48` |
| 6 | Handler önce **il var mı?** diye bakar. Yoksa `NotFoundException` fırlatır. | `Yukum.Application/Geography/GetDistrictsHandler.cs:15` |
| 7 | Depo, 81 ili **önbellekten** (yoksa veritabanından) alır ve 42 var mı diye bakar. | `Yukum.Infrastructure/Persistence/GeographyRepository.cs:38` |
| 8 | İlçeler istenir. Önbellekte yoksa EF Core şu SQL'i üretir (yaklaşık): `SELECT ... FROM Districts WHERE CityId = 42 ORDER BY Id`. | `Yukum.Infrastructure/Persistence/GeographyRepository.cs:50` |
| 9 | Veritabanı satırları (`District`) istemciye giden sade modele (`DistrictDto`: yalnız `id`, `name`) çevrilir. | `Yukum.Application/Geography/GetDistrictsHandler.cs:21` |
| 10 | `Ok(...)` ile **200** ve JSON döner. JSON kuralları: alanlar camelCase, tarihler UTC. | `Yukum.Api/Json/JsonSetup.cs:17` |
| 11 | Başlığa `Cache-Control: public,max-age=86400` eklenir: iOS 1 gün saklayabilir. | `Yukum.Api/Controllers/CitiesController.cs:22` |

**Hata yolu (il yoksa, örn. 999):** 6. adımdaki `NotFoundException` fırlar → `GlobalExceptionHandler` yakalar → `Describe` tablosu "404, Bulunamadı, İl bulunamadı." der → istemciye ProblemDetails JSON'u gider. Controller'da hiç `if` yazmadık.
`Yukum.Api/Middleware/GlobalExceptionHandler.cs:78`

**Önemli fikir:** Handler `IGeographyRepository` **arayüzünü** bilir, SQL Server'ı bilmez. Gerçeği (`GeographyRepository`) Infrastructure'dadır. Bu yüzden handler'ın testi, veritabanı olmadan sahte bir depoyla yapılabilir (`GeographyHandlersTests`).

---

## 3. Yolculuk 2: `POST /api/v1/auth/register/shipper` (Yük Veren kaydı)

| Adım | Ne oluyor | Nerede |
|---|---|---|
| 1 | İstemci JSON gövdesiyle gelir: `{ "fullName": "Ali Veli", "email": "...", "phone": "0532...", "password": "...", "cityId": 33, "kvkkAccepted": true }`. | [`docs/api/Auth.md`](api/Auth.md) |
| 2 | Adres `register/shipper` ise **rol de belli olur**: bu uç hep `Shipper` oluşturur, istemcinin "ben admin olayım" demesi işe yaramaz (gövdedeki `role` yok sayılır). | `Yukum.Api/Controllers/AuthController.cs:53` |
| 3 | `[ApiController]`, JSON'u `RegisterShipperCommand` nesnesine otomatik çevirir. Alanlar `?` (boş olabilir) tanımlı: eksik alan .NET'in İngilizce hatasıyla değil bizim Türkçe mesajımızla reddedilsin diye. | `Yukum.Application/Accounts/AccountContracts.cs:25` |
| 4 | Handler başlar. **Önce doğrulama:** geçersizse `ValidationException` → 400. | `Yukum.Application/Accounts/RegisterHandlers.cs:15` |
| 5 | Doğrulama kuralları: ad, e-posta biçimi, telefon, şifre (8+ ve büyük/küçük/rakam), KVKK, il var mı... Her kuralın **kendi Türkçe mesajı** var. | `Yukum.Application/Accounts/RegisterValidators.cs:73` |
| 6 | **Normalleştirme:** e-posta küçük harf, telefon `+905...`. Aynı kişi iki farklı yazılışla ikinci hesap açamasın. | `Yukum.Application/Accounts/RegisterHandlers.cs:18` |
| 7 | Telefonun nasıl çevrildiği (0532, +90 532, 532-123... hepsi aynı): | `Yukum.Application/Accounts/PhoneNumberNormalizer.cs:15` |
| 8 | Hesap servisi çağrılır. | `Yukum.Application/Accounts/RegisterHandlers.cs:32` |
| 9 | **TEK İŞLEM (transaction) başlar.** Bundan sonrası ya tamamen yazılır ya hiç. | `Yukum.Infrastructure/Identity/AccountService.cs:71` |
| 10 | Telefon kayıtlı mı? Kayıtlıysa `ConflictException` → 409. | `Yukum.Infrastructure/Identity/AccountService.cs:75` |
| 11 | Identity kullanıcıyı oluşturur: şifreyi **hash'ler** (açık saklanmaz), şifre kuralını ve benzersiz e-postayı denetler. | `Yukum.Infrastructure/Identity/AccountService.cs:92` |
| 12 | Rol verilir (`Shipper`). | `Yukum.Infrastructure/Identity/AccountService.cs:98` |
| 13 | Profil satırı eklenir (Yük Veren'in firma/il bilgisi). | `Yukum.Infrastructure/Identity/AccountService.cs:31` |
| 14 | `SaveChanges`: satırlar yazılır. `AppDbContext` bu anda `CreatedAt` damgasını **otomatik** koyar. | `Yukum.Infrastructure/Persistence/AppDbContext.cs:138` |
| 15 | **Commit:** işlem onaylanır. | `Yukum.Infrastructure/Identity/AccountService.cs:107` |
| 16 | **201 Created** + kullanıcı özeti (`id`, `fullName`, `email`, `userType`). Şifre ve hash dönmez. | `Yukum.Api/Controllers/AuthController.cs:59` |

**Hata yolları**
- **400:** Alan geçersiz (4. ve 5. adım). Cevap `errors` sözlüğüdür, anahtarlar camelCase; iOS her mesajı doğru kutunun altına koyabilir.
- **409:** E-posta ya da telefon kayıtlı (10. ve 11. adım). İki istek aynı anda gelirse ön kontrol ikisini de geçer, **veritabanının benzersiz indeksi** ikincisini reddeder; bu da 409'a çevrilir:
  `Yukum.Infrastructure/Identity/AccountService.cs:111`
- **Yarım hesap yok:** 12. ya da 14. adımda hata olursa `Commit`'e hiç gelinmez, işlem otomatik geri alınır (`AccountServiceTests` bunu kanıtlar).

**Önemli fikir:** Şifre kuralı tek yerde (`PasswordPolicy`); hem Türkçe doğrulama hem Identity aynı koddan okur, ayrışamaz.
`Yukum.Application/Accounts/PasswordPolicy.cs:29`

---

## 4. Yolculuk 3: `POST /api/v1/auth/login` (giriş ve jeton)

| Adım | Ne oluyor | Nerede |
|---|---|---|
| 1 | İstemci `emailOrPhone`, `password`, `deviceId` gönderir. | [`docs/api/Auth.md`](api/Auth.md) |
| 2 | Doğrulama: alanlar dolu mu? (şifre karmaşıklığı burada denetlenmez). | `Yukum.Application/Accounts/LoginValidator.cs:10` |
| 3 | Kimlik türü belirlenir: `@` varsa e-posta, değilse telefon; ikisi de değilse genel hata. | `Yukum.Application/Accounts/LoginHandler.cs:28` |
| 4 | Kullanıcı bulunur. **Yoksa bile** sahte bir şifre doğrulaması yapılır: cevap süresinden "bu e-posta kayıtlı mı" anlaşılmasın. | `Yukum.Infrastructure/Identity/AuthService.cs:30` |
| 5 | Kilitli mi? Kilitliyse şifreye hiç bakılmaz (423). | `Yukum.Infrastructure/Identity/AuthService.cs:38` |
| 6 | Şifre doğru mu? **Yanlışsa** sayaç artar; 5. hatada kilit başlar. | `Yukum.Infrastructure/Identity/AuthService.cs:42` |
| 7 | Hesap devre dışı/engelli mi? **Yalnız doğru şifreden sonra** söylenir (403). | `Yukum.Infrastructure/Identity/AuthService.cs:53` |
| 8 | Başarılı: hatalı deneme sayacı sıfırlanır, rol okunur. | `Yukum.Infrastructure/Identity/AuthService.cs:57` |
| 9 | **Jeton (JWT) üretilir:** içinde yalnız `sub` (kullanıcı), `role`, `jti`. 15 dk geçerli. İmza gizli anahtarla atılır. | `Yukum.Infrastructure/Identity/JwtTokenService.cs:28` |
| 10 | **200** + `accessToken`, bitiş zamanı, kullanıcı özeti. | `Yukum.Application/Accounts/LoginHandler.cs:45` |

**Jeton sonraki isteklerde nasıl kullanılır?** İstemci her korumalı istekte `Authorization: Bearer <jeton>` başlığı gönderir. API bunu şöyle denetler:
- İmza bizim anahtarımızla mı, süresi dolmuş mu, bu API/uygulama için mi? `Yukum.Api/Program.cs:80`
- Yalnız HS256 kabul edilir: `Yukum.Api/Program.cs:83`
- Hat sırasında önce kimlik, sonra yetki: `Yukum.Api/Program.cs:142`
- Bir uç `[Authorize(Roles = "Shipper")]` ile korunursa jetondaki `role` claim'ine bakılır. (Test uçları bunu kanıtlar: `AuthLoginApiTests`.)

**Hata yolları:** yanlış şifre/kullanıcı yok → **aynı 401**; 5 hata → **423** + `Retry-After`; hesap engelli → **403**. Hepsi tek yerde eşlenir:
`Yukum.Api/Middleware/GlobalExceptionHandler.cs:80`

---

## 5. Sık görülen C# kavramları (Swift karşılığıyla)

| C# | Anlamı | Swift'te |
|---|---|---|
| `record` | Değişmez veri taşıyıcı (komutlar, DTO'lar); `with` ile kopyalanıp bir kısmı değiştirilir | `struct` (+ kopyala-değiştir) |
| `string?` | "Boş olabilir" (null olabilir) | `String?` |
| `value!` | "Boş olmadığını ben biliyorum" | `value!` |
| `async` / `await` / `Task<T>` | Beklemeli iş (veritabanı, ağ) | `async` / `await` / `async -> T` |
| `interface` | Sözleşme: ne yapılacağını söyler, nasıl yapılacağını söylemez | `protocol` |
| Constructor injection `class X(IFoo foo)` | Gereken şeyi (ör. depo) sınıf kendi üretmez, dışarıdan **verilir** (`Program.cs` ve `DependencyInjection.cs` kayıt yapar) | Initializer ile bağımlılık vermek |
| `[HttpGet("...")]`, `[ApiController]` | Metodun/sınıfın üstüne yapışan etiket (öznitelik) | Property wrapper / macro gibi |
| LINQ: `.Where(x => ...).Select(...)` | Koleksiyon/sorgu zinciri; veritabanında **SQL'e çevrilir** | `filter`, `map` |
| `throw new XException(...)` | Hata fırlatır; `GlobalExceptionHandler` HTTP cevabına çevirir | `throw` (ama hata→cevap eşlemesi merkezde) |
| `Lazy<T>` | İlk kullanıldığında bir kez hesaplanır | `lazy var` |
| `Guid` | Tahmin edilemez uzun kimlik | `UUID` |

---

## 6. Testler nasıl okunur?

Testler `backend/tests` altında; **kodu anlamanın en hızlı yolu** testleri okumaktır, çünkü her biri "şu girdi → şu sonuç" diye yazılmıştır.

- `[Fact]` tek senaryo, `[Theory]` + `[InlineData(...)]` aynı testin birden çok girdiyle tekrarı.
- İsimler cümle gibidir: `A_wrong_password_and_an_unknown_user_return_the_same_401`.
- **Birim testler** (`Yukum.UnitTests`): veritabanı yok, sahte depo ile, milisaniyeler içinde.
- **Entegrasyon testleri** (`Yukum.IntegrationTests`): gerçek API + **gerçek SQL Server** (her koşuda Docker'da geçici bir tane açılır).
- Hangi dosya neyi kanıtlıyor: `GeographySeedTests` (81/973 doğru mu), `AccountsTests` (tablo kuralları), `AccountServiceTests` (tek işlem, çift kayıt), `AuthServiceTests` (kilit, süre), `AuthLoginApiTests` (uçtan uca giriş + jeton + rol), `CitiesApiTests`, `AuthRegisterApiTests`.
- Çalıştırma: `dotnet test backend/Yukum.slnx` (Docker açık olmalı).

---

## 7. "Şunu değiştirmek istersem nereye bakarım?"

| İstek | Dosya |
|---|---|
| Şifre kuralı (uzunluk, büyük harf...) | `Application/Accounts/PasswordPolicy.cs` (tek kaynak) + mesajlar `RegisterValidators.cs` |
| Telefon biçimleri | `Application/Accounts/PhoneNumberNormalizer.cs` |
| Doğrulama mesajları (Türkçe metinler) | `Application/Accounts/RegisterValidators.cs`, `LoginValidator.cs` |
| Jeton ömrü (15 dk) | `Api/appsettings.json` → `Jwt:AccessTokenMinutes` |
| Kilit eşiği (5 hata / 15 dk) | `Infrastructure/DependencyInjection.cs` → `options.Lockout...` |
| Yeni bir hata türü (örn. 429) | `Application/Common/` altına sınıf + `GlobalExceptionHandler.Describe` tablosuna bir satır |
| Yeni bir tablo | `Domain` sınıfı + `Infrastructure/Persistence/Configurations` sınıfı + `AppDbContext`'e `DbSet` + `dotnet ef migrations add` (+ önce test) |
| Yeni bir uç (endpoint) | `Application` komutu/handler + `Api/Controllers` metodu (+ önce test, + `docs/api` sözleşmesi) |
| JSON kuralları (tarih, enum) | `Api/Json/` |
| Araç tipi eklemek | `Domain/Accounts/VehicleType.cs` (**mevcut sayılar değişmez**, yenisi sona eklenir) |

---

## 8. Aşama aşama: iOS ↔ API ↔ Veritabanı (güncel tutulur)

Her aşamada "ne yapıldı, hangi kodla bağlandı" burada kısaca yazılır.

### Aşama 1: Kayıt (Yük Veren), ÇALIŞIYOR ✅
Akış: `RegisterView` → `AuthService` → API → SQL Server → geri.

| # | Ne oldu | Hangi kod |
|---|---|---|
| 1 | Kullanıcı formu doldurup "Kayıt Ol"a basar; alanlar boş mu, KVKK onaylı mı bakılır. | `ios/.../View/RegisterView.swift` (düğmenin içi) |
| 2 | Form bilgisi bir pakete konur. Alan adları API'dekiyle aynı. | `ios/.../Network/RegisterRequest.swift` → `RegisterRequest` |
| 3 | `JSONEncoder` paketi JSON'a çevirir. | `ios/.../Network/AuthService.swift` → `register` |
| 4 | `URLSession`, JSON'u `POST http://localhost:5054/api/v1/auth/register/shipper` adresine gönderir (API ile bağlantıyı kuran sınıf). | `AuthService.swift` → `register` |
| 5 | iOS'un yerel `http`ye izin vermesi gerekir (yoksa istek engellenir). | `ios/Yukum/Yukum/Info.plist` → `NSAllowsLocalNetworking` |
| 6 | API adresi dinler, gelen JSON'u nesneye çevirir. | `backend/.../Controllers/AuthController.cs` → `RegisterShipper` |
| 7 | Alanlar kontrol edilir; hata varsa 400 + Türkçe mesaj. | `backend/.../Accounts/RegisterValidators.cs` |
| 8 | Şifre hash'lenir, kullanıcı + profil tek işlemde yazılır. | `backend/.../Identity/AccountService.cs` |
| 9 | SQL Server'a yazılır. Bağlantı adresi/parolası `user-secrets`'ta. | `backend/.../DependencyInjection.cs` (`UseSqlServer`), `AppDbContext.cs` |
| 10 | API `201 Created` döner. | `AuthController.cs` |
| 11 | iOS cevabı `RegisterResponse` paketine çevirir; hata varsa `APIErrorResponse` içindeki Türkçe mesajı alır. | `RegisterRequest.swift`, `AuthService.swift` |
| 12 | Ekranda yeşil "Kayıt başarılı" ya da kırmızı hata yazısı çıkar. | `RegisterView.swift` (`isSuccess`, `errorMessage`) |

Kontrol: VS Code mssql ile `Users` tablosunda kayıt görülür; API tarayıcıdan `http://localhost:5054/scalar` ile denenir.

### Sıradaki aşamalar (sırayla)
2. Rol seçim ekranı (Yük Veren / Taşımacı) → `RoleSelectionView`
3. Taşımacı kaydı → `CarrierRegisterView` + `AuthService.registerCarrier` (API ucu hazır: `register/carrier`)
4. Giriş → `LoginRequest/LoginResponse`, `AuthService.login`, `LoginView` düğmesi (API ucu hazır: `login`)
5. Anasayfa, ilan verme ve detaylar
