# Sözleşme kartı: Favoriler, görüntülenme ve ilan sayıları

Taban adres `/api/v1`, jeton gerekir.

## Taşımacı
- `PUT /listings/{id}/favorite` → 204. İlanı favoriler. **İdempotent:** zaten favoriyse de 204, sayı şişmez.
- `DELETE /listings/{id}/favorite` → 204. Favoriden çıkarır. Favori değilse de 204.
- `GET /listings/favorites` → `[ListingDto]`. Favori ve **hâlâ açık** ilanlar, son favorilenen üstte (kaldırılan/atanan ilan düşer). Her satırda `isFavorite: true`.
- `POST /listings/{id}/view` → 204. İlan detayı açılınca çağrılır. Aynı Taşımacı aynı gün (UTC) kaç kez çağırsa **1** sayılır.
- `GET /listings` (açık ilan listesi) satırlarında artık `isFavorite` (bool) gelir: kalp dolu/boş.
- 404: ilan yok. 403: Yük Veren bu uçları kullanamaz.

## Yük Veren (ilan sahibi)
- `GET /listings/{id}/stats` → `{ "viewCount": 12, "favoriteCount": 3, "offerCount": 2 }`. Yalnız ilanın sahibi görür; başkasının ilanı 404, Taşımacı 403.
- `offerCount`: geri çekilen teklifler sayılmaz.

## Sayılar nasıl tutulur
Ayrı sayaç sütunu yok. `FavoriteListings` ve `ListingViews` tablolarındaki benzersiz satırlar sayılır (`COUNT`). (Kullanıcı, ilan) ve (ilan, kişi, gün) üzerindeki **benzersiz indeks** çifte kaydı veritabanında engeller; iki istek aynı anda gelse bile sayı şişmez.
