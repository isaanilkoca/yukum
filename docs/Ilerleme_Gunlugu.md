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
<!--C1-->

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
- Doğrulama **mesaj metinleri** İngilizce → D2'de FluentValidation ile Türkçe.
- ~~Uygulamanın user-secrets'tan bağlantıyı gerçekten okuması~~ → B3c-2'de doğrulandı.
- HTTPS yönlendirme uyarısı (http profili) → C3'te iOS bağlantısıyla netleşecek.
- Apple Developer hesabı ücretsiz: push (Aşama I), TestFlight (F6) ve App Store (K) öncesi ücretli hesap gerekir.

### Sıradaki (yarın buradan devam)
**C1b** (Cities/Districts entity'leri + EF yapılandırması + migration + seed; veri testleri), sonra C2 (`GET /cities`, `GET /cities/{id}/districts`, 404 için ilk hata eşlemesi), sonra iOS tarafına geçiş (C3–C5, kullanıcı yazar). Aşama B tamamlandı (B5 Docker Compose + CI "ilk çalışır hâlden sonra" olarak ertelendi).
