#!/bin/bash
# Gün başı: Docker → SQL konteyneri → API açılır, sağlık kontrolü yapılır, günlüğün son satırları gösterilir.
# Kapalı olanı açar, açık olana dokunmaz (tekrar çalıştırmak güvenli). Parola/anahtar yazdırmaz.
cd "$(dirname "$0")/../.." || exit 1

# 1) Docker Desktop (en çok 60 sn bekler)
if ! docker info >/dev/null 2>&1; then
  open -a Docker
  for _ in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 2; done
fi
docker info >/dev/null 2>&1 && echo "Docker: açık" || { echo "Docker: AÇILAMADI"; exit 1; }

# 2) SQL Server konteyneri
docker start yukum-sql >/dev/null 2>&1
sleep 6
docker exec yukum-sql bash -c '/opt/mssql-tools18/bin/sqlcmd -C -I -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -d Yukum -W -h -1 -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM Listings"' 2>/dev/null | head -1 | sed 's/^/SQL: açık, ilan sayısı = /'

# 3) API (5054 boşsa başlatır)
if ! lsof -ti:5054 >/dev/null 2>&1; then
  (dotnet run --project backend/src/Yukum.Api --launch-profile http >/tmp/yk-api.log 2>&1 &)
  for _ in $(seq 1 20); do curl -s -o /dev/null localhost:5054/api/v1/cities && break; sleep 2; done
fi
echo "API /cities: $(curl -s -o /dev/null -w '%{http_code}' localhost:5054/api/v1/cities) | /listings/mine (jetonsuz): $(curl -s -o /dev/null -w '%{http_code}' localhost:5054/api/v1/listings/mine) (beklenen 200 ve 401)"

# 4) Nerede kaldık
echo "--- Günlüğün son satırları ---"
tail -4 docs/Ilerleme_Gunlugu.md | cut -c1-300
git status --short | head -5
