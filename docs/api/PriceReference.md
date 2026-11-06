# Sözleşme kartı: Emsal fiyat

`GET /api/v1/price-reference?fromCityId=33&toCityId=34&vehicleType=Truck` (giriş yapmış herkes)

- Aynı kalkış ili, varış ili ve araç tipi için **son 180 günde karara bağlanmış, TAMAMLANMIŞ** işlerin kabul edilen tutarlarının **medyanı** (ortanca değer).
- Cevap 200: `{ "medianAmount": 2000.00, "sampleCount": 3 }`
- **En az 3 tamamlanmış iş** yoksa `medianAmount` **null** döner (200 OK, hata değil); iOS bu durumda hiçbir şey göstermez. `sampleCount` o zamana kadar bulunan iş sayısıdır.
- En çok son 200 iş hesaba katılır.
- 400: `fromCityId`/`toCityId` ≤ 0 ya da `vehicleType` geçersiz/eksik. 401: jeton yok.
- **Neden medyan, ortalama değil:** tek bir uç tutar (1 ₺ ya da 1.000.000 ₺) ortalamayı bozar, medyanı bozmaz.
- iOS: ilan detayında "Bu rotada emsal fiyat ₺X (son N iş)".
