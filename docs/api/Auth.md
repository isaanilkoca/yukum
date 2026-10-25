# Sözleşme kartı: Kayıt (Auth — register)

iOS tarafı bu karta göre yazılır. Backend bunu test ediyor (`AuthRegisterApiTests`); kart ile cevap arasında fark olursa hata backend'dedir, haber verin.

- **Taban adres:** `/api/v1` (yerel: `http://localhost:5054`)
- **Oturum:** Gerekmez (anonim).
- **Biçim:** JSON, alan adları camelCase, enum değerleri metin (örn. `"Truck"`).
- **Kapsam:** Yalnız **kayıt**. Giriş (`/auth/login`), jeton yenileme ve `/me` sonraki adımlarda (D3–D5) gelecek. Kayıt başarılı olunca kullanıcı **giriş yapmış olmaz**; giriş ayrı uçtan yapılır.
- **Rol:** İstemci rol/tür göndermez. Hangi uca gidersen o rolle kaydolursun (`/shipper` → Yük Veren, `/carrier` → Taşımacı). Gövdeye `role` ya da `userType` yazsanız yok sayılır.

## Ortak kurallar (iki kayıt ucu için)

| Alan | Kural |
|---|---|
| `fullName` | Zorunlu, 2–150 karakter. Ad-soyad ya da firma adı. |
| `email` | Zorunlu, geçerli biçim, en çok 254. Küçük harfe çevrilip saklanır; **bir e-posta tek hesap**. |
| `phone` | Zorunlu, Türkiye cep telefonu. `0532 123 45 67`, `532-123-4567`, `+90 532 123 45 67` gibi biçimler kabul edilir, `+905321234567` olarak saklanır. **Bir telefon tek hesap.** |
| `password` | Zorunlu, **8–128 karakter; en az bir büyük harf, bir küçük harf, bir rakam**. Sembol zorunlu değil. Türkçe harfler geçerlidir (`Şifre1234`). |
| `kvkkAccepted` | Zorunlu, **`true`** olmalı. Onay anı sunucuda saklanır. |

iOS'ta aynı kuralları formda önceden denetleyip hızlı geri bildirim verebilirsiniz, ama **son söz sunucudadır**; sunucu hatası her zaman ekranda gösterilmeli.

## 1. Yük Veren kaydı

`POST /api/v1/auth/register/shipper`

```json
{
  "fullName": "Ali Veli",
  "email": "ali@example.com",
  "phone": "0532 123 45 67",
  "password": "Abcdefg1",
  "cityId": 33,
  "companyName": "Ali Tarım",
  "taxNumber": "1234567890",
  "taxOffice": "Mersin",
  "kvkkAccepted": true
}
```

| Alan | Zorunlu | Kural |
|---|---|---|
| `cityId` | Evet | Plaka kodu; `GET /cities`'ten gelen `id` (bkz. `Cities.md`). |
| `companyName` | Hayır | En çok 200 karakter. |
| `taxNumber` | Hayır | Verilirse 10 veya 11 haneli rakam. |
| `taxOffice` | Hayır | En çok 100 karakter. |

## 2. Taşımacı kaydı

`POST /api/v1/auth/register/carrier`

```json
{
  "fullName": "Veli Nakliyat",
  "email": "veli@example.com",
  "phone": "0533 222 11 00",
  "password": "Abcdefg1",
  "homeCityId": 33,
  "serviceCityIds": [33, 1, 34],
  "vehicles": [
    { "type": "Truck", "plateNumber": "33 ABC 123", "capacityKg": 24000, "capacityVolume": 90 },
    { "type": "Refrigerated", "capacityKg": 8000 }
  ],
  "kvkkAccepted": true
}
```

| Alan | Zorunlu | Kural |
|---|---|---|
| `homeCityId` | Evet | Merkez ilinin plaka kodu. |
| `serviceCityIds` | Hayır | Çalıştığı illerin plaka kodları; tekrarsız, hepsi geçerli. |
| `vehicles` | **Evet, en az 1** | En çok 20 araç. |
| `vehicles[].type` | Evet | `Truck` (Tır), `Lorry` (Kamyon), `Pickup` (Kamyonet), `Refrigerated` (Frigorifik), `Other` (Diğer). |
| `vehicles[].capacityKg` | Evet | 1–100000 (kg). |
| `vehicles[].plateNumber` | Hayır | En çok 20 karakter. |
| `vehicles[].capacityVolume` | Hayır | Verilirse 0'dan büyük, en çok 200 (m³). |

## Başarılı cevap (iki uç için aynı)

**201 Created**

```json
{
  "id": "2a8bfccf-4ce4-475b-6129-08df32b15af5",
  "fullName": "Ali Veli",
  "email": "ali@example.com",
  "userType": "Shipper"
}
```

`userType`: `Shipper` ya da `Carrier`. Şifre ve hash **asla** dönmez. `email` küçük harfe çevrilmiş halidir.

## Hata cevapları (hepsi ProblemDetails)

**400 Bad Request** — bir ya da daha fazla alan geçersiz. `errors` sözlüğünün anahtarı alan adıdır (camelCase), değeri **kullanıcıya gösterilebilir Türkçe mesajlar** listesidir:

```json
{
  "title": "Doğrulama hatası",
  "status": 400,
  "detail": "Bir veya daha fazla alan geçersiz.",
  "errors": {
    "email": ["Geçerli bir e-posta adresi girin."],
    "password": ["Şifre en az bir büyük harf içermeli."],
    "kvkkAccepted": ["Devam etmek için KVKK aydınlatma metnini onaylamanız gerekir."],
    "vehicles[1].capacityKg": ["Taşıma kapasitesi 0'dan büyük olmalı."]
  },
  "traceId": "00-4ceac3ffd87067d9..."
}
```

Liste içindeki hata, dizinle gelir: `vehicles[1].capacityKg` = ikinci aracın kapasitesi. Bozuk JSON ya da bilinmeyen enum değeri de 400 döner (bu durumda mesaj İngilizce olabilir; normal kullanımda oluşmamalı).

**409 Conflict** — e-posta ya da telefon zaten kayıtlı. `detail` gösterilebilir:

```json
{
  "title": "Çakışma",
  "status": 409,
  "detail": "Bu e-posta adresiyle zaten bir hesap var.",
  "traceId": "00-aa453a62..."
}
```

`detail` ya `Bu e-posta adresiyle zaten bir hesap var.` ya da `Bu telefon numarasıyla zaten bir hesap var.` olur.

**500** — beklenmeyen hata, içerik sızmaz; `traceId` ile destek istenebilir.

## Swift karşılığı (öneri)

```swift
enum VehicleType: String, Codable, CaseIterable {
    case truck = "Truck", lorry = "Lorry", pickup = "Pickup", refrigerated = "Refrigerated", other = "Other"
}

struct VehicleInput: Codable {
    var type: VehicleType
    var plateNumber: String?
    var capacityKg: Int
    var capacityVolume: Double?
}

struct RegisterShipperRequest: Codable {
    var fullName, email, phone, password: String
    var cityId: Int
    var companyName, taxNumber, taxOffice: String?
    var kvkkAccepted: Bool
}

struct RegisterCarrierRequest: Codable {
    var fullName, email, phone, password: String
    var homeCityId: Int
    var serviceCityIds: [Int]?
    var vehicles: [VehicleInput]
    var kvkkAccepted: Bool
}

struct RegisteredUser: Codable, Identifiable {
    let id: UUID
    let fullName: String
    let email: String
    let userType: String   // "Shipper" | "Carrier"
}
```

`VehicleType` için ileride yeni değer eklenebilir; iOS'ta bilinmeyen değer çökmeye yol açmamalı (örn. `case unknown` ile `init(from:)`).

## Notlar
- Şifre sunucuda geri döndürülemez biçimde saklanır (hash). Şifreyi cihazda saklamayın; giriş sonrası verilecek jetonlar Keychain'e yazılır (D6).
- Kayıt tek işlemdir: bir adım başarısız olursa hiçbir şey kaydedilmez, yarım hesap kalmaz.
- Hız sınırı (çok sık deneme) D5'te eklenecek.
