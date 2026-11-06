# Yüküm API imajı | çok aşamalı (multi-stage): derleme araçları son imaja girmez, imaj küçük ve güvenli kalır
# Kullanım: docker compose up (kökteki docker-compose.yml bu dosyayı kullanır) | DERLEME BAĞLAMI = depo kökü (il/ilçe verisi docs/veri/ içinde, projeye gömülür)

# 1) Derleme aşaması: .NET SDK ile projeyi yayınlar (publish)
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
# Önce yalnız proje dosyaları: paketler ayrı katmanda önbelleğe alınır, kod değişince yeniden indirilmez
COPY backend/Yukum.slnx ./
COPY backend/src/Yukum.Domain/Yukum.Domain.csproj src/Yukum.Domain/
COPY backend/src/Yukum.Application/Yukum.Application.csproj src/Yukum.Application/
COPY backend/src/Yukum.Infrastructure/Yukum.Infrastructure.csproj src/Yukum.Infrastructure/
COPY backend/src/Yukum.Api/Yukum.Api.csproj src/Yukum.Api/
RUN dotnet restore src/Yukum.Api/Yukum.Api.csproj
COPY backend/src/ src/
# proje ../../../docs/veri yoluyla okur: /src/src/Yukum.Infrastructure -> /docs/veri
COPY docs/veri/il-ilce.json /docs/veri/il-ilce.json
RUN dotnet publish src/Yukum.Api/Yukum.Api.csproj -c Release --no-restore -o /app

# 2) Çalışma aşaması: yalnız ASP.NET çalışma zamanı + yayınlanan dosyalar
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
# Günlük dosyaları için yazılabilir klasör; sonra root olmayan kullanıcıya geçilir ($APP_UID imajda hazır gelir)
RUN mkdir -p logs && chown $APP_UID logs
USER $APP_UID
COPY --from=build /app .
# .NET 8+ imajları varsayılan olarak 8080'de dinler (root olmayan kullanıcı 80'e bağlanamaz)
EXPOSE 8080
ENTRYPOINT ["dotnet", "Yukum.Api.dll"]
