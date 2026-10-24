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
<!--B3C-->

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

### Sıradaki
**B3** (veritabanı: taban sınıf, AppDbContext, ilk migration, `/health` DB kontrolü), sonra B4 (Repository + Unit of Work).
