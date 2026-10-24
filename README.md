# Yüküm

Yük Veren'in ilan açtığı, Taşımacı'nın ilana fiyat teklifi verdiği açık pazar mobil uygulaması.

| Katman | Teknoloji |
|---|---|
| Backend | .NET 10, ASP.NET Core Web API, EF Core 10, Clean Architecture + CQRS-lite |
| Veritabanı | Microsoft SQL Server 2025 (Docker) |
| iOS | Swift, SwiftUI, MVVM + Router |

## Klasörler
- `backend/` — Web API ve testleri
- `ios/` — iOS uygulaması
- `docs/` — Teknik rapor, uygulama planı, karar kayıtları

Yapım sırası: `docs/Yukum_Adim_Adim_Uygulama_Plani.pdf`

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
4. API'yi çalıştır: `dotnet run --project backend/src/Yukum.Api --launch-profile http` → http://localhost:5054/scalar
5. Testler: `dotnet test backend/Yukum.slnx`

İlerleme: `docs/Ilerleme_Gunlugu.md`
