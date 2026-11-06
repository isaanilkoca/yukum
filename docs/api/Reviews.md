# Sözleşme kartı: İş aşamaları, Puan/Yorum, Taşımacı profili

iOS bu karta göre yazılır. Backend `OffersAndChatApiTests` içinde test ediyor. Taban adres `/api/v1`, jeton gerekir (`Authorization: Bearer ...`).

## 1. İş aşaması ilerletme
`POST /offers/{offerId}/advance` (yalnız **Taşımacı**, gövde yok)
- Cevap 200: `{ "id": "...", "stage": "PickedUp" }`. Sıra: `NotStarted → PickedUp (yük alındı) → InTransit (yolda) → Delivered (teslim edildi)`. Atlama ve geri alma yok.
- 404: teklif yok ya da başkasının. 403: Yük Veren. 409: iş kabul edilmemiş ya da zaten `Delivered`.
- Aşama `GET /offers/mine` (Taşımacı) ve `GET /offers/history` (Yük Veren) satırlarında `stage` alanıyla gelir.
- **Kural:** `POST /offers/{id}/complete` ("İşi bitir") yalnız `Delivered` aşamasından sonra çalışır, öncesinde 409 "Önce yük teslim edilmeli."

## 2. Puan ve yorum
`POST /offers/{offerId}/review` (yalnız **Yük Veren**)
```json
{ "rating": 5, "comment": "Zamanında teslim etti." }
```
- `rating`: 1–5 zorunlu. `comment`: isteğe bağlı, en çok 500 karakter.
- Cevap 201: `{ "id", "offerId", "rating", "comment" }`.
- 400: puan 1–5 dışında ya da yorum uzun. 404: iş yok ya da başkasının. 409: iş `Completed` değil, ya da bu işe zaten puan verilmiş. 403: Taşımacı.
- Aynı işlemde Taşımacı'nın `averageRating` ve `ratingCount` değeri güncellenir.
- `GET /offers/history` satırında `reviewed` (bool) gelir: `true` ise "Puan ver" düğmesi gizlenir.

## 3. Taşımacı profili
`GET /carriers/{carrierId}` (giriş yapmış herkes)
```json
{
  "id": "...", "fullName": "Veli Nakliyat", "about": null,
  "averageRating": 4.50, "ratingCount": 2, "completedJobCount": 3,
  "reviews": [
    { "rating": 5, "comment": "Harika", "shipperName": "Ali V.", "listingTitle": "Mobilya",
      "fromCityName": "Mersin", "toCityName": "İstanbul", "createdAt": "2026-11-07T10:00:00Z" }
  ]
}
```
- `reviews`: en yeni 20 yorum. Yük Veren adı kısaltılır ("Ali V.").
- 404: Taşımacı yok.
- Yük Veren'in teklif listesi (`GET /listings/{id}/offers`) her satırda `carrierId`, `carrierRating`, `carrierRatingCount` taşır; iOS bununla profile gider.
