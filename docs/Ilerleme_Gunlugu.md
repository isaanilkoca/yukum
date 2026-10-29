# İlerleme Günlüğü

Her çalışma gününün sonunda "bugün ne yaptık" adım adım buraya yazılır. Yeni oturum buradan devam eder.
Bağlayıcı sıra: `Yukum_Adim_Adim_Uygulama_Plani.pdf`. Kararlar: `Karar_Kayitlari.md`.

---

## 25 Ekim 2026 — Gün 1: Hazırlık (Aşama A) ve backend temeli (B1–B2)

**Çalışma şekli:** Backend + veritabanını Claude yazıyor (kısa adım → doğrula → rapor), iOS'u kullanıcı yazacak. Test önce yazılır (kırmızı), sonra uygulanır (yeşil).

### Aşama A — Hazırlık
| Adım | Ne yapıldı | Kanıt |
|---|---|---|
| A1 | Kurulumlar: .NET SDK 10.0.402, VS Code 1.143 + C# Dev Kit, Docker Desktop (motor 29.9, Compose v5.6). SQL Server **2025** konteyneri `yukum-sql` (port 1433, kalıcı birim `yukum-sql-data`, amd64 emülasyonu). Sudo gerektirdiği için kurulumları kullanıcı Terminal'de yaptı. | `dotnet --version` = 10.0.402; konteynerde `SELECT @@VERSION` cevap verdi |
| A2 | Depo düzeni `backend/ ios/ docs/`, `.gitignore`, README, `git init`, GitHub'da public repo `isaanilkoca/yukum` | `bdd7bc3` |
| A3 | Ürün adı **Yukum**, bundle ID `com.isaanilkoca.yukum` (K-001). SQL Server 2022 yerine 2025 (K-010). Tasarım kararı C3'e ertelendi (K-011). | `bac634c` |
| A4 | Ertelendi (renk/font iOS projesi açılmadan önce) | K-011 |

### Aşama B — Backend temeli
| Adım | Ne yapıldı | Kanıt |
|---|---|---|
| B1 | `Yukum.slnx`; projeler Domain, Application, Infrastructure, Api + UnitTests, IntegrationTests. Bağımlılık yönü: Api→Application→Domain, Infrastructure→Application. `GET /health`, Scalar arayüzü (`/scalar`). Şablonun örnek WeatherForecast kodu silindi. | `73a10fd`; health 200, Scalar 200 |
| B2a | Global hata yakalayıcı: beklenmeyen hata → 500 `application/problem+json` + `traceId`, **iç detay istemciye sızmaz** (yalnız sunucu logunda). | `e9a83bc`; 4 senaryo elle denendi |
| B2b | Serilog: konsol + günlük dosya (`logs/`, 14 gün), istek günlüğü, her log satırında `traceId` (hata cevabındakiyle aynı). Ayar `appsettings.json`'da. | `4dcd3c9`; cevap ve log aynı traceId |
| B2c | API sürümleme `/api/v1` (Asp.Versioning + sürüm başına OpenAPI belgesi). JSON: camelCase, enum string, tarih **UTC `…T07:15:00Z` kesirli saniyesiz** (Swift `.iso8601` kesirliyi okuyamaz). Doğrulama hatalarında alan adları camelCase, başlık Türkçe. | `ad6145b`; **15 entegrasyon testi yeşil**, 0 uyarı |
| B2d | `Yukum` veritabanı, en az yetkili `yukum_app` kullanıcısı (sunucu yöneticisi değil), bağlantı bilgisi **user-secrets**'ta. Parola repoda ve git geçmişinde yok (arandı). | `62139a2` |

### Aşama B devam — veritabanı katmanı (B3)
| Adım | Ne yapıldı | Kanıt |
|---|---|---|
| B3a | `BaseEntity` (Domain): `Id`, `CreatedAt`, `UpdatedAt`, `IsDeleted`, `RowVersion`. Id'yi EF Core üretir (SQL Server sıralı GUID, K-012). | `715486d` |
| B3b | `AppDbContext` (Infrastructure): kaydetmeden önce `CreatedAt`/`UpdatedAt` (UTC, `TimeProvider` ile), **yumuşak silme** (`Remove` → `IsDeleted=true`, sorgularda otomatik gizli), `RowVersion` ile eşzamanlılık denetimi. Davranışlar **gerçek SQL Server 2025'e karşı** (Testcontainers, testin kendi geçici DB'si) 5 testle kanıtlandı; testler önce kırmızıydı. | **20 entegrasyon + 1 birim test yeşil** |

**B3b'de yakalanan güvenlik uyarısı:** EF SQL Server paketinin dolaylı getirdiği `System.Security.Cryptography.Pkcs 9.0.11` paketinde bilinen yüksek/orta açık vardı (NU1902/NU1903). Uyarıyı susturmadık; yamalı 10.0.13 sürümünü Infrastructure'a doğrudan ekledik, zafiyet taraması temiz.

#### B3c — ilk migration, DI bağlantısı, `/health` DB kontrolü (adım adım)
| Alt adım | Ne yapıldı | Kanıt |
|---|---|---|
| B3c-1 | `dotnet-ef` 10.0.13 projeye özel kuruldu (`backend/dotnet-tools.json`); sudo/global kurulum gerekmedi. | `dotnet ef --version` = 10.0.13 |
| B3c-2 | `AddInfrastructure()` (DbContext + `TimeProvider`, bağlantı dizesi kullanılırken okunur; eksikse açık hata mesajı). `/health` artık **veritabanına bağlanmayı dener**: erişilebilirken 200 Healthy, DB ulaşılamaz ya da ayar eksikken 503 Unhealthy. | 3 health testi + **gerçek API gerçek `Yukum` DB'sine user-secrets ile bağlanıp Healthy döndü** (B2d borcu kapandı) |
| B3c-3 | İlk migration `InitialCreate` (boş şema: gerçek tablolar Aşama D'den itibaren). Geliştirme DB'sine `dotnet ef database update` ile uygulandı. İki test: migration'lar boş DB'ye temiz uygulanır; modelde migration'a yazılmamış değişiklik yok (ileride birinin migration eklemeyi unutmasını yakalar). | SQL Server'da `Yukum` içinde `__EFMigrationsHistory` + `20261024232737_InitialCreate`; **24 entegrasyon + 1 birim test yeşil** |
<!--B3C-->

#### B4 — Repository, Unit of Work, CQRS-lite (adım adım)
| Alt adım | Ne yapıldı | Kanıt |
|---|---|---|
| B4a | Application katmanında arayüzler: `IRepository<T>` (GetById, List, Any, Count, Add, Remove; okumada `asNoTracking`), `IUnitOfWork` (tek işlemde kaydet), `ICommandHandler`/`IQueryHandler`. **Rapordan bilinçli fark:** `Update` metodu yok — EF izlenen kaydın değişikliğini zaten kaydediyor; `Update` tüm sütunları baştan yazan bir tuzak. Kopuk (detached) kayıt senaryosu çıkarsa eklenir. | Derleme temiz; davranış testi B4b'de |
| B4b | `Repository<T>` ve `UnitOfWork` (Infrastructure), `AddRepositories()` ile DI kaydı. 7 davranış testi (önce iskeletle hepsi kırmızıydı): ekle→bul, olmayan Id null, izlenen kaydın değişikliği `Update` olmadan kaydedilir, **silinen kayıt GetById/List/Count/Any'de görünmez ama satır durur**, predicate'li list/count/any, `asNoTracking` gerçekten izlemez, **atomiklik: çakışmada aynı kaydetmedeki yeni kayıt da kaydedilmez**. `FindAsync` bilerek kullanılmadı (yumuşak silme filtresini atlar). | **31 entegrasyon + 1 birim test yeşil**, 0 uyarı |
| B4c | CQRS-lite kaydı: `AddApplication()` Application projesindeki handler sınıflarını **kendisi bulup** scoped kaydeder (yeni handler yazınca başka yere dokunulmaz). Kurallar: soyut ve iç içe (nested) sınıflar kaydedilmez; aynı komut için **iki farklı handler → uygulama açılırken hata**; iki kez taramak çift kayıt üretmez. Handler iş mantığı **sahte repo (NSubstitute)** ile veritabanısız test edildi (bulunca günceller+tek kaydet; bulamazsa kaydetmez; sorgu `asNoTracking` okur). Uçtan uca: DI→handler→repo→UoW→gerçek SQL Server, yazma ve okuma ayrı oturumda. | **8 birim + 32 entegrasyon test yeşil**, 0 uyarı; gerçek API `/health` Healthy |
<!--B4-->

### Aşama C — il/ilçe (C1)
| Alt adım | Ne yapıldı | Kanıt |
|---|---|---|
| C1a | **Veri seti hazırlandı ve doğrulandı** (kod yok, yalnız veri): 81 il, 973 ilçe, plaka kodları, il ve ilçe merkezi koordinatları. 5 kaynak çapraz kontrol edildi (Vikipedi iki tablo, GeoNames, Wikidata, 2 GitHub seti). "922 mi 973 mü?" tuzağı çözüldü: 922 belediye sayısı, 973 idari ilçe; "Merkez" ilçesi sayısı tam 51. **Bulunan hatalar:** Wikidata'da Konya ve Uşak plakası yanlış; Vikipedi'de 9 ilçe koordinatı yanlış (5'i başka ilçenin koordinatının kopyası). Hepsi düzeltildi. | `docs/veri/il-ilce.json`, `docs/veri/Veri_Kaynaklari.md`, K-013; değişmez kontrolleri geçti |
| C1b-1 | **Varlık sınıfları ve kırmızı testler.** `City` (Id = plaka kodu) ve `District` (Id = sıralı 1–973, `CityId` ile ile bağlı) yazıldı. İkisi de `BaseEntity`'den **türemez**: o sınıfın Id'si GUID, bunların Id'si plaka/sıra numarası, ayrıca sabit referans verisi oldukları için silinme/değişme/RowVersion'a ihtiyaçları yok. 18 test yazıldı: 81/973 sayıları, plaka kodları (Konya 42, Uşak 64...), her il ve ilçenin `il-ilce.json` ile birebir eşleşmesi, ilçe numaralarının donmuş sırası (1 = Adana/Aladağ, 973 = Düzce'nin son ilçesi), il başına ilçe sayısı, aynı ilde tekrar eden ilçe adı ve tekrar eden il adının reddi, olmayan ile bağlı ilçenin reddi. | Testler **kırmızı**: 18/18 başarısız, sebep doğru ("City/District modelde yok"); `Domain/Geography/City.cs`, `District.cs`, `tests/.../Data/GeographySeedTests.cs` |
| C1b-2/3 | **Tablolar, seed ve migration.** `AppDbContext`'e `Cities` ve `Districts` eklendi; her tablonun kuralları ayrı sınıfta (`Persistence/Configurations`): il adı benzersiz, ilçe adı aynı ilde benzersiz, ilçe mutlaka bir ile bağlı (`Restrict`). Seed `docs/veri/il-ilce.json`'dan okunur (dll'e gömülü, `GeographySeed`). Migration `AddCitiesAndDistricts` üretildi ve **geliştirme veritabanına uygulandı**. K-014 yazıldı. | **58/58 test yeşil** (18 yeni). SQL'de doğrulama: 81 il, 973 ilçe, ilçesiz il 0, yetim ilçe 0, 51 "Merkez", Konya=42, Uşak=64, Id 1 = Aladağ, Id 973 = Düzce/Yığılca; `__EFMigrationsHistory`'de 2 kayıt |
| C2 | **İlk gerçek API uçları.** `GET /api/v1/cities` (81 il) ve `GET /api/v1/cities/{cityId}/districts` (ilin ilçeleri): anonim, sunucuda `IMemoryCache` 24 saat, istemciye `Cache-Control: public, max-age=86400`. Özel `IGeographyRepository` (il/ilçe GUID'li `BaseEntity` olmadığı için genel `IRepository` uymaz). İlk uygulama hata türü `NotFoundException` → `GlobalExceptionHandler` 404 ProblemDetails ("İl bulunamadı."); 404 `no-store`. İstemciye yalnız `id` ve `name` gider. iOS için sözleşme kartı yazıldı. K-015. | **84/84 test yeşil** (11 birim + 73 entegrasyon; 26 yeni: handler, repository+önbellek, API+OpenAPI). Gerçek API gerçek veritabanıyla curl'le denendi: 81 il, Konya 31 ilçe, 404 doğru, OpenAPI'de iki yol. `docs/api/Cities.md` |
<!--C1-->

### Aşama D — Kimlik (Login / Register / Auto-login)
| Alt adım | Ne yapıldı | Kanıt |
|---|---|---|
| D1 | **Kimlik tabloları.** ASP.NET Core Identity (GUID anahtarlı) eklendi; `Users`, `Roles`, `UserRoles`..., `ShipperProfiles`, `CarrierProfiles`, `Vehicles`, `CarrierServiceCities` (çalışma bölgeleri), `RefreshTokens`. Roller seed edildi (Admin, Shipper, Carrier). Araç tipleri: Tır, Kamyon, Kamyonet, Frigorifik, Diğer. E-posta ve telefon benzersizliği veritabanında; kullanıcı silinince profili, aracı, jetonu birlikte silinir; yenileme jetonunda `RowVersion` ile yarış durumu yakalanır. Identity paketi güvenlik taramasından geçti. K-016. | **108/108 test yeşil** (24 yeni, `AccountsTests`). Migration `AddAccounts` geliştirme veritabanına uygulandı; SQL'de doğrulandı: 11 yeni tablo, 3 rol, tek ve benzersiz `EmailIndex`, benzersiz telefon (boşsa filtreli) ve jeton indeksleri, 81 il korundu. Kendi yakaladığım hata: ilk migration'da `NormalizedEmail` için gereksiz ikinci indeks çıktı, düzeltilip yeniden üretildi |
| D2 | **Kayıt uçları.** `POST /api/v1/auth/register/shipper` ve `/register/carrier` (anonim, 201 + kullanıcı özeti, oturum açmaz). İlk kez **FluentValidation ve Türkçe doğrulama mesajları** (bilinen borç kapandı); şifre kuralı 8–128, büyük+küçük+rakam, tek kaynakta (`PasswordPolicy`) ve Identity'ye de aynı kod bağlı; telefon her yazılışta `+905…` biçimine çevrilir; e-posta küçük harfe; Taşımacı'da en az 1 araç; KVKK onayı zorunlu. Hesap **tek işlemde** kurulur (kullanıcı+rol+profil+araç+bölge), çift e-posta/telefon **409** (eşzamanlı çift kayıt da). Yeni hata türü `ConflictException`; `GlobalExceptionHandler` 400/404/409/500 üretir. iOS için sözleşme kartı (`docs/api/Auth.md`). K-017. | **211/211 test yeşil** (91 birim + 120 entegrasyon; D2 için 103 yeni: şifre/telefon/doğrulayıcı/handler, hesap servisi gerçek SQL Server ile, API uçtan uca). Gerçek API gerçek veritabanıyla curl'le denendi (201, 409, 400 Türkçe mesajlar), kayıt satırı SQL'de doğrulandı (rol, `+905…`, 84 karakterlik hash), **log dosyalarında açık şifre yok**, silinince cascade çalıştı, test kullanıcıları temizlendi. Yazarken yakalanan risk: Identity'nin ASCII-yalnız harf kontrolü "Şifre1234"ü reddedip 500 üretirdi → tek kaynak + özel Identity doğrulayıcı |
| D3 | **Giriş.** `POST /api/v1/auth/login` (e-posta **ya da** telefonla; telefon her yazılışta tanınır): 200 + erişim jetonu (JWT, 15 dk, yalnız `sub`/`role`/`jti`) + bitiş zamanı + kullanıcı özeti. Yanlış şifre ile olmayan kullanıcı **aynı 401** ("E-posta veya şifre hatalı."), olmayan kullanıcıda da şifre doğrulama süresi harcanır; 5 hatada **423** + `Retry-After` (kilitliyken doğru şifre de reddedilir, başarıda sayaç sıfırlanır); pasif/engelli hesap doğru şifreyle 403. JwtBearer doğrulaması: yalnız HS256, imza + yayıncı + hedef + süre; süresi dolmuş / yanlış anahtar / yanlış hedef jetonlar 401, rol uyuşmazlığı 403. İmza anahtarı yalnız user-secrets'ta, kısa/eksikse uygulama açılırken durur. Hata eşlemeleri tek yerde (`GlobalExceptionHandler` yeniden düzenlendi). Sözleşme kartı güncellendi (`docs/api/Auth.md`). K-018. | **279/279 test yeşil** (114 birim + 165 entegrasyon; D3 için 68 yeni: doğrulayıcı, handler, JWT içeriği/imzası/ömrü/ayar doğrulaması, hesap servisi gerçek SQL Server ile kilit senaryoları, API uçtan uca + jetonlu korumalı uçlar + rol testi). Gerçek API gerçek veritabanı ve gerçek JWT anahtarıyla denendi: giriş (telefonla, Türkçe şifreyle), 4×401 sonra 423 + `Retry-After: 900`, olmayan kullanıcı aynı 401; jeton yükü kontrol edildi; **loglarda şifre/jeton/e-posta yok**; test kullanıcısı temizlendi |
<!--D-->

### Açıklama ve rapor paketi (25 Ekim 2026, D3'ten sonra)
| Ne | Ne yapıldı | Kanıt |
|---|---|---|
| Satır satır kod açıklaması | API, Application ve Infrastructure katmanındaki tüm dosyalara önemli satırlarda Türkçe `//` açıklaması eklendi (sınıf/metot `///` açıklamaları zaten vardı). Yalnız yorum: davranış değişmedi | 301 satır eklendi, **0 silindi**, derleme ve doküman denetimi 0 uyarı, **279/279 test yeşil**; commit `409e739` |
| Kod anlatımı | `docs/Kod_Anlatimi.md`: katmanlar, ilk gün okuma sırası, üç isteğin (il/ilçe, kayıt, giriş) dosya + satır numaralı yolculuğu, C#↔Swift sözlüğü, "şunu değiştirmek istersem nereye bakarım" | Satır numaraları koddan otomatik hesaplandı (53 referans) |
| SQL rehberi | `docs/SQL_Rehberi.md` (veritabanına nasıl bakılır: VS Code eklentisi, terminal, API; şema diyagramı; örnek sorgular — hepsi gerçek veritabanında denendi; terimler) ve `docs/veri/Sema.sql` (EF'in ürettiği gerçek `CREATE TABLE`/indeks komutları, her sütunun yanında Türkçe açıklama) | Şema doğrudan SQL Server'dan okunup yazıldı |
| iOS yol haritası | `docs/iOS_Yol_Haritasi.md`: "backend bitince mi?" sorusunun cevabı (hayır, dilim dilim), neyin hazır olduğu tablosu, C3–C5 ve D6–D8 adım adım (dosya/klasör/ayar, "bitti" ölçütü, takılınca nasıl yazılır) | Rapor Bölüm 10–11'e dayalı |
| İlerleme raporu (PDF, 12 sayfa) | Abisine göstermek için: özet rakamlar, plan ilerlemesi, mimari, canlı API ekran görüntüsü, veritabanı şeması, güvenlik, testler, **Graphify kod haritası görüntüsü**, kod örnekleri, sıradaki adımlar ve dürüst notlar | Masaüstünde `Yukum_Ilerleme_Raporu.pdf`; plan ilerlemesi 12/57 adım (%21), MVP yolunda 12/34 (%35) |

### Gün 1 kapanış özeti (25 Ekim 2026)
**Bugün biten:** Aşama A (hazırlık) ve Aşama B (backend temeli) tamamen; Aşama C'nin veri hazırlığı (C1a).
**Elde olan:** çalışan Web API iskeleti (/health, Scalar, /api/v1, hata formatı, loglama, JSON kuralları), veritabanı katmanı (AppDbContext, yumuşak silme, RowVersion, migration), Repository + Unit of Work + CQRS-lite handler yapısı, doğrulanmış 81 il / 973 ilçe verisi.
**Sayılar:** 40 otomatik test yeşil (8 birim + 32 entegrasyon), 0 uyarı, 0 hata, bilinen güvenlik açığı yok; GitHub'da 18 commit.
**Henüz yok (bilerek):** gerçek tablolar/controller'lar, iOS projesi, Docker Compose + CI (B5), kimlik (Aşama D).

**Dokümantasyon düzeni (her adımda güncellenir):**
- Kodun içinde: her sınıf ve herkese açık metotta `/// <summary>` açıklaması (VS Code'da hover ile görünür, Swift'teki `///` gibi).
- `docs/Ilerleme_Gunlugu.md` — ne yaptık, adım adım (bu dosya).
- `docs/Karar_Kayitlari.md` — neden öyle karar verdik (K-001…K-013).
- `docs/Backend_Rehberi.md` — hangi araç/paket/dosya/kavram ne işe yarar, komutlar, Swift karşılıkları.
- `docs/veri/Veri_Kaynaklari.md` — il/ilçe verisinin kaynakları ve doğrulama yöntemi.

**Yeni oturumu başlatırken:** bu dosyayı ve `Backend_Rehberi.md`'yi oku; `git log --oneline | head`; Docker açık mı, `yukum-sql` çalışıyor mu (`docker ps`); `dotnet test backend/Yukum.slnx` yeşil mi. Sonra aşağıdaki "Sıradaki"den devam.

### Öğrenilenler / dürüst notlar
- Bir test beklentimi tahminle yazmıştım (olmayan sürüm için 400); gerçek davranış 404 çıktı, testi gerçek gereksinime göre düzelttik.
- `.csproj` satır sonları karışıktı, `user-secrets init` tek biçime getirdi (tek seferlik gürültü).
- Test uçları yalnız test projesinde; gerçek API'ye girmedi.

**B3c-2'de yakalanan iki hata (ikisi de düzeltildi):**
1. Test, geliştiricinin user-secrets'ına bağımlıydı ("bağlantı yok" senaryosunda gerçek DB'ye bağlanıp 200 verdi). Test fabrikası artık bağlantıyı varsayılan boş verir; başka bilgisayarda/CI'da aynı sonuç.
2. Hazır `AddDbContextCheck`, ayar eksikken hatayı yakalamayıp 500 döndürdü. Kendi `DatabaseHealthCheck`'imizi yazdık: her hata 503 Unhealthy, ayrıntı yalnız loga. Gereksiz paket kaldırıldı.

### Bilinen borçlar
- **OpenAPI/Scalar şema cilası:** Scalar'da bazı örnek alanlar yanıltıcı görünüyor (`accessTokenExpiresAt` örneği `1`, sayılar "integer | string", opsiyonel alanlar "required"). **Gerçek cevaplar doğru ve testli**; yalnız deneme sayfasındaki örnek/şema. E aşamasında sözleşme kartlarıyla birlikte cilalanacak.
- E-posta/telefon doğrulama kodu ve şifre sıfırlama henüz yok (planda D'de değil; kapsam kararı bekliyor).
- ~~Doğrulama mesaj metinleri İngilizce~~ → D2'de FluentValidation ile Türkçe oldu. Kalan: bozuk JSON / bilinmeyen enum değerinde .NET'in İngilizce mesajı (normal kullanımda oluşmaz).
- ~~Uygulamanın user-secrets'tan bağlantıyı gerçekten okuması~~ → B3c-2'de doğrulandı.
- HTTPS yönlendirme uyarısı (http profili) → C3'te iOS bağlantısıyla netleşecek.
- Apple Developer hesabı ücretsiz: push (Aşama I), TestFlight (F6) ve App Store (K) öncesi ücretli hesap gerekir.

### Sıradaki (yarın buradan devam)
Aşama C (il/ilçe) **bitti**. Aşama D'de **D1 (tablolar), D2 (kayıt) ve D3 (giriş) bitti**. Sıradaki: **D4** yenileme jetonu (girişte `refreshToken` döner, her yenilemede rotasyon, çalıntı jeton tekrar kullanılırsa cihazın tüm jeton ailesi iptal, `/auth/refresh`, `/auth/logout`), sonra **D5** (yetki politikaları ShipperOnly/CarrierOnly/AdminOnly, giriş/kayıt için hız sınırı, `GET /me`, yetki matrisi testi). **D5 bitince iOS'a geçiş zamanı**: C3–C5 (Xcode projesi, API istemcisi, il/ilçe ekranı) ve D6–D8 (Keychain/token, giriş-kayıt ekranları, otomatik giriş) kullanıcıya aittir; sözleşmeler `docs/api/Cities.md` ve `docs/api/Auth.md`. B5 (Docker Compose + CI) "ilk çalışır hâlden sonra" ertelendi.

### 29 Ekim 2026 — iOS giriş aşaması (Swift merkezli döngü)
- `Network/LoginRequest.swift` (LoginRequest, LoginUser, LoginResponse), `AuthService.login` eklendi; `post` genelleştirildi (`Body: Encodable, Response: Decodable`, 200...299 başarı). Derleme geçti.
- `LoginView`: "Giriş yap" bağlandı (kontrol, isLoading, hata yazısı), "Kayıt ol" → `RoleSelectionView` (NavigationLink; iç içe NavigationStack kaldırıldı). `ContentView` ilk ekranı `LoginView`.
- Otomasyon: `.claude/hooks/swift-build-check.sh` (iOS .swift değişince sessiz derleme, hata varsa bildirir; kayıt `.claude/settings.local.json`'da, git dışı).
- Açık: başarılı giriş sonrası yönlendirme (role'e göre anasayfa) yok; simülatörde giriş denemesi kullanıcıda.
- Karar: Swift merkezli dilim döngüsü (Yük Veren anasayfası → ilan ucu/DB → Taşımacı anasayfası → teklif ucu). Backend yalnız ekranın ihtiyacı kadar.
- (29 Ekim, akşam) Giriş uçtan uca denendi (simülatör, çalışıyor). `HomeView(user:)` eklendi; giriş başarılıysa `fullScreenCover(item:)` ile role göre anasayfa yazısı açılıyor, "Çıkış yap" dismiss ile döner. Sıradaki: Yük Veren "İlan ver" formu (Swift), sonra ilan ucu/DB.
- (30 Ekim) İlan ver formu tamam ve simülatörde denendi: `Network/CityModels.swift` (City, District), `Network/CityService.swift` (cities, districts), `View/CreateListingView.swift` (başlık, açıklama, ağırlık, kalkış/varış il→ilçe Picker'ları, araç, tarih, bütçe, kontroller). İl listesi API'den geliyor (81). Düğme henüz API'ye bağlı değil, konsola `İLAN HAZIR` yazıyor. Sıradaki: backend `Listings` tablosu + ilan oluştur/ilanlarım uçları (Claude), sonra formu bağlama + jeton saklama (Swift).
