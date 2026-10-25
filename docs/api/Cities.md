# Sözleşme kartı: İl / İlçe (Cities)

iOS tarafı bu karta göre yazılır. Backend bunu test ediyor (`CitiesApiTests`); kart ile cevap arasında fark olursa hata backend'dedir, haber verin.

- **Taban adres:** `/api/v1` (yerel: `http://localhost:5054`)
- **Oturum:** Gerekmez (anonim). Kayıt ekranında giriş yapmadan da kullanılır.
- **Biçim:** JSON, alan adları camelCase.
- **Önbellek:** Başarılı cevaplarda `Cache-Control: public, max-age=86400` (1 gün). Liste cihazda saklanabilir; yılda birkaç kez değişir.

## 1. İl listesi

`GET /api/v1/cities`

**200 OK** — 81 il, plaka koduna (`id`) göre artan sırada:

```json
[
  { "id": 1,  "name": "Adana" },
  { "id": 2,  "name": "Adıyaman" },
  { "id": 42, "name": "Konya" }
]
```

| Alan | Tür | Anlam |
|---|---|---|
| `id` | Int | **Plaka kodu** (1–81). İlan gibi başka kayıtlarda il bu numarayla saklanır. |
| `name` | String | İlin adı (Türkçe karakterli). |

## 2. İlçe listesi

`GET /api/v1/cities/{cityId}/districts`

`cityId`: ilin plaka kodu (Int).

**200 OK** — o ilin ilçeleri, Türkçe alfabetik sırada (`id` artan):

```json
[
  { "id": 562, "name": "Ahırlı" },
  { "id": 563, "name": "Akören" },
  { "id": 564, "name": "Akşehir" }
]
```

| Alan | Tür | Anlam |
|---|---|---|
| `id` | Int | İlçe numarası (1–973). **Donmuştur**, değişmez. İlanlarda ilçe bu numarayla saklanır. |
| `name` | String | İlçenin adı. Farklı illerde aynı ad olabilir (örn. 51 ilde "Merkez"); ilçe her zaman ilinin altında seçilir. |

**404 Not Found** — il yok (örn. `/cities/999/districts`). Gövde ProblemDetails:

```json
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.5",
  "title": "Bulunamadı",
  "status": 404,
  "detail": "İl bulunamadı.",
  "traceId": "00-98a7ec9037e43ca44eb66d45a8a35488-7e6d7b2d4f35f9ff-00"
}
```

`detail` kullanıcıya gösterilebilir. `Cache-Control: no-cache, no-store` gelir, 404 saklanmaz. `cityId` sayı değilse (`/cities/abc/districts`) de 404 döner.

## Swift karşılığı (öneri)

```swift
struct City: Codable, Identifiable, Hashable {
    let id: Int      // plaka kodu
    let name: String
}

struct District: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}
```

Cascade seçici akışı: il seçilince `GET /cities/{id}/districts` çağrılır; il değişince seçili ilçe sıfırlanır. İlan oluştururken `cityId` ve `districtId` olarak bu numaralar gönderilir (serbest metin değil).

## Notlar
- Koordinatlar (enlem/boylam) veritabanında var ama **istemciye gönderilmez**; mesafe hesabı sunucuda yapılacak.
- Yeni ilçe eklenirse sıradaki numarayı alır, mevcut numaralar değişmez (K-013).
