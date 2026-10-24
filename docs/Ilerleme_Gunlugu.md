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

### Öğrenilenler / dürüst notlar
- Bir test beklentimi tahminle yazmıştım (olmayan sürüm için 400); gerçek davranış 404 çıktı, testi gerçek gereksinime göre düzelttik.
- `.csproj` satır sonları karışıktı, `user-secrets init` tek biçime getirdi (tek seferlik gürültü).
- Test uçları yalnız test projesinde; gerçek API'ye girmedi.

### Bilinen borçlar
- Doğrulama **mesaj metinleri** İngilizce → D2'de FluentValidation ile Türkçe.
- Uygulamanın user-secrets'tan bağlantıyı gerçekten okuması B3'te uçtan uca doğrulanacak.
- HTTPS yönlendirme uyarısı (http profili) → C3'te iOS bağlantısıyla netleşecek.
- Apple Developer hesabı ücretsiz: push (Aşama I), TestFlight (F6) ve App Store (K) öncesi ücretli hesap gerekir.

### Sıradaki
**B3** (veritabanı: taban sınıf, AppDbContext, ilk migration, `/health` DB kontrolü), sonra B4 (Repository + Unit of Work).
