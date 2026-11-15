# Yüküm

Yük Veren'in ilan açtığı, Taşımacı'nın ilana fiyat teklifi verdiği açık pazar mobil uygulaması.

| Katman | Teknoloji |
|---|---|
| Backend | .NET 10, ASP.NET Core Web API, EF Core 10, Clean Architecture + CQRS-lite |
| Veritabanı | Microsoft SQL Server 2025 (Docker) |
| iOS | Swift 6, SwiftUI, MVVM (@Observable) + protokol tabanlı DI, async/await + actor, Keychain, APNs |
| Test | xUnit + Testcontainers (backend), Swift Testing + XCUITest (iOS), GitHub Actions CI |

## Klasörler
- `backend/` — Web API ve testleri (klasör haritası + bütün API uçları: `docs/Backend_Rehberi.md`)
- `ios/` — iOS uygulaması (her klasörün ilk dosyası `00_Rehber_….swift`: o klasörde ne var, ne işe yarar, hangi uca gider)
- `docs/` — Teknik rapor, uygulama planı, karar kayıtları, rehberler

Yapım sırası: `docs/Yukum_Adim_Adim_Uygulama_Plani.pdf`

## Hızlı başlangıç (Docker, tek komut)
Gerekenler: Docker Desktop. API ve SQL Server birlikte ayağa kalkar; tablolar ve 81 il / ilçe verisi açılışta kendiliğinden kurulur.
```
cp .env.example .env        # DB_PASSWORD ve JWT_SIGNING_KEY değerlerini değiştir (.env Git'e girmez)
docker compose up --build
```
- API: http://localhost:5054/scalar (deneme sayfası) · sağlık: http://localhost:5054/health
- iOS uygulaması varsayılan olarak `localhost:5054`'e bağlanır, ek ayar gerekmez.
- Durdurmak: `docker compose down` · veriyi de silmek: `docker compose down -v`
- Bu yol, aşağıdaki "Geliştirme ortamı kurulumu" ile aynı sonucu verir; kod yazarken `dotnet run` (hızlı yeniden başlatma), demo ve kurulum için Docker kullanılır.

**Bu kurulumdaki teknik tercihler**
- Çok aşamalı `backend/Dockerfile`: SDK ile derle, yalnız çalışma zamanı imajına kopyala, root olmayan kullanıcıyla çalıştır.
- `docker-compose.yml`: SQL Server sağlık kontrolü geçmeden API başlamaz (`depends_on: service_healthy`); gizli değerler `.env`'den gelir, kodda yoktur.
- `Database:MigrateOnStartup`: açılışta EF Core migration'ları uygulanır (yalnız compose'ta açık).
- `.github/workflows/backend.yml` (GitHub Actions): her push/PR'da derleme + birim ve entegrasyon testleri (Testcontainers ile gerçek SQL Server) + Docker imajı derleme kontrolü.

## Geliştirme ortamı kurulumu (backend)
Gerekenler: .NET 10 SDK, Docker Desktop, VS Code (C# Dev Kit).

1. SQL Server 2025 konteyneri (Apple Silicon'da amd64 emülasyonuyla çalışır):
   ```
   docker run -d --name yukum-sql --platform linux/amd64 \
     -e ACCEPT_EULA=Y -e "MSSQL_SA_PASSWORD=<güçlü-parola>" -e MSSQL_PID=Developer \
     -p 1433:1433 -v yukum-sql-data:/var/opt/mssql mcr.microsoft.com/mssql/server:2025-latest
   ```
2. `Yukum` veritabanını ve en az yetkili `yukum_app` kullanıcısını oluştur (SA yalnız yönetim içindir).
3. Bağlantı dizesi **Git'e girmez**, user-secrets'a yazılır:
   ```
   dotnet user-secrets set "ConnectionStrings:DefaultConnection" \
     "Server=localhost,1433;Database=Yukum;User Id=yukum_app;Password=<parola>;TrustServerCertificate=True;Encrypt=True" \
     --project backend/src/Yukum.Api
   ```
   Erişim jetonu (JWT) imza anahtarı da **Git'e girmez**; en az 32 karakterlik rastgele bir değer üret ve user-secrets'a yaz
   (anahtarı bilen herkes sahte giriş jetonu üretebilir). Canlıda ortam değişkeni `Jwt__SigningKey` kullanılır:
   ```
   dotnet user-secrets set "Jwt:SigningKey" "$(openssl rand -base64 48)" --project backend/src/Yukum.Api
   ```
   (Issuer, Audience ve jeton ömrü gizli değildir, `appsettings.json` içindeki `Jwt` bölümündedir. Anahtar yoksa uygulama açılırken açık bir hatayla durur.)
4. API'yi çalıştır: `dotnet run --project backend/src/Yukum.Api --launch-profile http` → http://localhost:5054/scalar
5. Veritabanı şemasını uygula: `dotnet tool restore` (bir kez) sonra
   `dotnet ef database update --project backend/src/Yukum.Infrastructure --startup-project backend/src/Yukum.Api`
   (araç `backend` klasöründe kurulu; komutları `backend/` içinde çalıştır)
6. Testler: `dotnet test backend/Yukum.slnx` (veritabanı testleri Docker'da kendi geçici SQL Server'ını açar)

## Dokümantasyon
- `docs/Ilerleme_Gunlugu.md` — günlük ilerleme, adım adım
- `docs/Kod_Anlatimi.md` — **kodu nasıl okursun**: üç gerçek isteğin (il/ilçe, kayıt, giriş) dosya ve satır numaralı yolculuğu
- `docs/SQL_Rehberi.md` + `docs/veri/Sema.sql` — veritabanı: tablolar, ilişkiler, örnek sorgular, açıklamalı şema
- `docs/Backend_Rehberi.md` — hangi araç/paket/dosya ne işe yarar, komutlar, Swift karşılıkları
- `docs/Eposta_Sistemi.md` — e-posta doğrulama + şifremi unuttum: kod nereye gider, Resend anahtarı nerede
- `docs/sql/` — hazır sorgular (teklifler, şikâyet/engelleme incelemesi)
- `docs/api/` — API sözleşme kartları (Auth, Account, Cities, Listings, Favorites, Reviews, Notifications, PriceReference); canlı belge: `/scalar`
- `docs/Karar_Kayitlari.md` — neden öyle karar verdik (K-001 … K-024)
- `docs/veri/Veri_Kaynaklari.md` — il/ilçe verisinin kaynakları ve doğrulama yöntemi
- Kod içinde: her sınıf, metot ve önemli satırda Türkçe açıklama (`///` ve `//`)
