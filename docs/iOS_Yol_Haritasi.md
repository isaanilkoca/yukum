# iOS Yol Haritası (adım adım)

Bu belge **senin yazacağın iOS tarafı** için. Her adımda: ne oluşturacaksın, hangi dosya, ne içerecek, "bitti" ne zaman sayılır, takılırsam ne yapacağım. Takıldığın yerde bana yaz; hata mesajını, hangi dosyada olduğunu ve ne beklediğini söylemen yeter.

> Ana kaynaklar: [`Yukum_Teknik_Rapor.pdf`](Yukum_Teknik_Rapor.pdf) Bölüm 10–12 (iOS tasarımı), [`Yukum_Adim_Adim_Uygulama_Plani.pdf`](Yukum_Adim_Adim_Uygulama_Plani.pdf) (sıra), API sözleşmeleri: [`api/Cities.md`](api/Cities.md) ve [`api/Auth.md`](api/Auth.md).

---

## 0. "iOS'a backend bitince mi geçeceğiz?" Hayır, iç içe gideceğiz

Plan, backend ve iOS'u **dilim dilim** birlikte ilerletir: backend'de bir parça bitince, iOS'ta onun ekranı yapılır; böylece her seferinde "telefondan gerçekten çalışıyor mu?" diye denenir. Backend'in tamamını bitirip sonra iOS'a geçmek, hataları geç görmek demektir.

**Şu anda backend'de ne hazır, ne değil?**

| Backend parçası | Durum | iOS'ta karşılığı | Şimdi yapabilir misin? |
|---|---|---|---|
| İl / ilçe listesi (C2) | ✅ Hazır, test edilmiş | **C3, C4, C5** (proje, API istemcisi, il/ilçe ekranı) | **Evet, hemen** |
| Kayıt: Yük Veren ve Taşımacı (D2) | ✅ Hazır | **D7** (kayıt ekranları) | Evet (C5'ten sonra) |
| Giriş (D3) | ✅ Hazır (yenileme jetonu yok) | **D7** (giriş ekranı) | Evet (C5'ten sonra) |
| Jeton yenileme, çıkış (D4) | ⏳ Sıradaki backend işi | **D6** (Keychain, otomatik yenileme) | Hayır, D4 bitince |
| `/me`, yetki, hız sınırı (D5) | ⏳ | **D8** (otomatik giriş, role göre ana ekran) | Hayır, D5 bitince |
| İlan (E) | ❌ Başlanmadı | E5, E6 (ilan ver, ilan listesi) | Hayır |
| Teklif (F) | ❌ | F5 (teklif ekranları) | Hayır |
| Puan/yorum, favori, bildirim, konum, yayın (G–K) | ❌ | G5, H3, I5, J2, J4, K3 | Hayır |

**Yani şimdi iOS'a başlayabilirsin:** C3 → C4 → C5, sonra D7'nin kayıt ve giriş ekranları. D6 ve D8 için D4/D5'i bekle. Ben backend'de D4, D5'e devam ederken sen paralel gidebilirsin; D5 bitince sana haber vereceğim.

---

## 1. Başlamadan önce 3 karar

| # | Karar | Önerim | Neden |
|---|---|---|---|
| 1 | **Minimum iOS sürümü** (rapordaki açık soru Q12) | **iOS 18** | Rapor da bunu öneriyor; cihazların büyük kısmını kapsar, modern SwiftUI/Observation kullanılır |
| 2 | **Renk ve yazı tipi** (K-011, C3'e ertelenmişti) | Lacivert `#10243F`, turuncu `#F26B1D`, sistem yazı tipi (SF Pro), simgeler SF Symbols | Hazır, ücretsiz, tutarlı; sonra değiştirmek kolay (renkler tek yerde olacak) |
| 3 | **Uygulama adı / paket kimliği** (K-001) | Ad **Yüküm**, Bundle ID `com.isaanilkoca.yukum` | Daha önce kararlaştırıldı |

Bunlara "tamam" ya da farklı bir tercih söylemen yeterli. Karar gelmeden C3'ü başlatabilirsin; renkler zaten sonra eklenecek.

> **Not (Apple hesabı):** Ücretsiz hesapla simülatörde ve kendi telefonunda deneyebilirsin. Push bildirimi, TestFlight ve App Store için **ücretli Apple Developer** hesabı gerekir (Aşama I ve K öncesi).

---

## 2. C3: Xcode projesini oluştur ("boş uygulama simülatörde açılıyor")

**Ne yapacaksın**

1. Xcode'u aç → **File → New → Project…** → **iOS → App** → Next.
2. Alanları şöyle doldur:
   - **Product Name:** `Yukum`
   - **Team:** Personal Team (Apple hesabın)
   - **Organization Identifier:** `com.isaanilkoca` (Bundle ID otomatik `com.isaanilkoca.Yukum` olur; sorun değil, istersen sonra küçük harfe çevirebilirsin)
   - **Interface:** SwiftUI · **Language:** Swift
   - **Storage:** None · **Testing System:** Swift Testing · **Include Tests** işaretli
3. Kaydetme yeri: `~/Desktop/yükümüTası/ios/` klasörünün **içi**. "Create Git repository" **işaretli olmasın** (zaten bir repo var).
4. Proje ayarlarında (**Target → General → Minimum Deployments**) iOS sürümünü **18.0** yap.
5. Klasör yapısını kur (**Xcode'da sağ tık → New Group**, rapordaki §10.3 yapısı):

```
Yukum/
├── App/              (YukumApp.swift buraya taşınır)
├── Core/
│   └── Networking/  (C4'te dolacak)
├── DesignSystem/
│   └── Theme/       (renkler)
├── Features/
│   └── Locations/   (C5: il/ilçe ekranı)
└── Resources/
```

6. **Taban adresi (base URL) ayarı:** Backend adresi koda gömülmez, ayar dosyasından okunur:
   - **File → New → File → Configuration Settings File** ile `Debug.xcconfig` ve `Release.xcconfig` oluştur. Debug içine şu satırı yaz (**`//` yazılamadığı için `$()` hilesi gerekir**, aynen yaz):
     ```
     API_BASE_URL = http:/$()/localhost:5054
     ```
   - Project → Info → **Configurations** bölümünde Debug ve Release'e bu dosyaları ata.
   - Target → **Info** sekmesine `API_BASE_URL` anahtarı ekle, değeri `$(API_BASE_URL)` olsun. Kodda `Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL")` ile okunur.
7. **HTTP izni (ATS):** iOS varsayılan olarak `http://` adreslerini engeller. Yerel geliştirme için Target → Info sekmesinde **App Transport Security Settings → Allow Local Networking = YES** ekle. (`localhost` simülatörde Mac'inin kendisidir, çalışır.)
8. **Renkleri tek yerde tanımla:** `DesignSystem/Theme/` içine `Colors.swift` aç; lacivert ve turuncuyu orada tanımla. Hiçbir ekranda ham renk kodu yazma.

**Bitti sayılır:** Simülatörde (iPhone 16 ya da güncel biri) `Cmd+R` ile boş uygulama açılıyor.
**Commit:** `ios: C3 Xcode project, folder structure, base URL config`

**Çalıştırma kontrolü için backend'i aç** (ayrı Terminal'de):
```
cd ~/Desktop/yükümüTası
docker start yukum-sql
dotnet run --project backend/src/Yukum.Api --launch-profile http
```
Tarayıcıda `http://localhost:5054/scalar` açılıyorsa API ayakta.

---

## 3. C4: Genel API istemcisi (`APIClient`)

**Amaç:** "Ben şu adrese şu istekle gideceğim, cevap şu modele çevrilsin" diye **tek bir genel metot**. Yeni bir uç eklemek = yeni bir `Endpoint` tanımlamak (ağ kodu tekrar yazılmaz). Rapor §11.

**Oluşturacağın dosyalar** (`Core/Networking/` altında):

| Dosya | İçeriği |
|---|---|
| `HTTPMethod.swift` | `enum HTTPMethod: String { case get = "GET", post = "POST", put = "PUT", delete = "DELETE" }` |
| `Endpoint.swift` | `struct Endpoint`: `path` (örn. `/api/v1/cities`), `method`, `queryItems`, `requiresAuth` (şimdilik hep `false`). Bir `urlRequest(baseURL:)` üretici |
| `APIError.swift` | `enum APIError: Error`: `offline`, `unauthorized` (401), `forbidden` (403), `notFound` (404), `conflict` (409), `locked(retryAfter:)` (423), `validation([String: [String]])` (400), `server`, `decoding` |
| `ProblemDetails.swift` | `struct ProblemDetails: Decodable` (sunucunun hata cevabı: `title`, `status`, `detail`, `errors`, `traceId`) |
| `APIClient.swift` | `protocol APIClient` + gerçek `URLSessionAPIClient`. Tek metot: `func send<Response: Decodable>(_ endpoint: Endpoint, body: Encodable?) async throws -> Response` |

**Kurallar (sunucu sözleşmesi):**
- JSON alan adları **camelCase** (Swift ile aynı, ek ayar gerekmez).
- Tarihler UTC ve kesirsiz (`2026-10-25T17:11:31Z`): `JSONDecoder.dateDecodingStrategy = .iso8601` yeterli.
- Hata cevabı `application/problem+json`: `status` koduna bakıp `ProblemDetails`'i çöz, uygun `APIError`'a çevir. `errors` sözlüğünün anahtarı alan adıdır (`email`, `vehicles[1].capacityKg`).
- Kullanıcıya gösterilecek Türkçe mesaj sunucudan **hazır** gelir (`detail` ya da `errors`); kendin çevirme.
- Ağ yoksa `URLError` (`.notConnectedToInternet`) → `APIError.offline`.

**Test (Swift Testing):** Sahte `URLProtocol` yazıp gerçek ağa gitmeden şunları dene: 200 başarılı çözülür; 404 ProblemDetails `APIError.notFound` olur; 400 `errors` doğru ayrışır; ağ yoksa `offline`. (Bunun nasıl kurulacağını takılırsan birlikte yaparız.)

**Bitti sayılır:** testler yeşil.
**Commit:** `ios: C4 generic APIClient with ProblemDetails mapping and tests`

---

## 4. C5: İl/ilçe ekranı ("cascade picker", simülatörde API'den gelen liste görünüyor)

**Sözleşme:** [`api/Cities.md`](api/Cities.md). `GET /api/v1/cities` ve `GET /api/v1/cities/{id}/districts`, giriş gerekmez.

**Oluşturacağın dosyalar** (`Features/Locations/` altında; rapordaki feature yapısı: `Views / ViewModels / Models / Services`):

| Dosya | İçeriği |
|---|---|
| `Models/City.swift`, `District.swift` | `struct City: Codable, Identifiable, Hashable { let id: Int; let name: String }` (aynısı `District` için; kart sonundaki Swift önerisine bak) |
| `Services/LocationService.swift` | `protocol LocationService { func cities() async throws -> [City]; func districts(cityId: Int) async throws -> [District] }` + `APIClient` kullanan gerçek sınıf. **Protokol** olmasının sebebi: testte sahtesini vermek |
| `ViewModels/LocationPickerViewModel.swift` | `@Observable @MainActor final class`. Durum: `cities`, `districts`, `selectedCity`, `selectedDistrict`, `LoadState` (`idle / loading / loaded / failed`). İl seçilince `districts`'i yükler, seçili ilçeyi sıfırlar |
| `Views/LocationPickerView.swift` | İki `Picker`: il, ilçe. **Üç durumu da göster:** yükleniyor (ProgressView), hata (mesaj + "Tekrar dene"), boş |

**Dikkat edilecekler**
- `@MainActor`: arayüzü değiştiren kod ana iş parçacığında çalışmalı.
- `.task { await viewModel.loadCities() }` ile ekran açılınca yükle.
- İl değişince önceki ilçe seçimi **mutlaka** sıfırlansın.
- Hata mesajı `APIError`'dan gelen Türkçe metin olsun.

**Bitti sayılır (milestone):** Simülatörde il listesi API'den geliyor; "Konya" seçince 31 ilçe listeleniyor; olmayan bir durumda (API kapalı) hata ekranı çıkıyor, "Tekrar dene" çalışıyor.
**Commit:** `ios: C5 city/district cascade picker with loading/error/empty states`

---

## 5. D6: Keychain, TokenStore, AuthInterceptor (D4 bitince)

Backend'de **D4 (yenileme jetonu)** bitince yapılır. Önceden bilmen gerekenler:
- **`KeychainService`:** Jetonları saklar. **`UserDefaults`'a asla jeton yazma** (şifresiz, yedeğe girer). Erişim sınıfı: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- **`TokenStore`:** Keychain'i sarmalar: `accessToken`, `refreshToken`, `accessTokenExpiresAt`.
- **`AuthInterceptor`:** Her isteğe `Authorization: Bearer <accessToken>` ekler; **401** gelirse **bir kez** yeniler ve isteği tekrar dener.
- **Yarış durumu:** Aynı anda 5 istek 401 alırsa 5 ayrı yenileme atılmaz; bir **`actor`** tek yenilemeyi yapar, diğerleri sonucunu bekler. Test: 5 paralel 401 → 1 yenileme.

Detay ve kod desteğini D4 bitince birlikte yaparız.

---

## 6. D7: Karşılama, giriş ve kayıt ekranları

**Sözleşme:** [`api/Auth.md`](api/Auth.md). Kayıt ve giriş uçları **şimdiden hazır**.

**Ekranlar (`Features/Auth/`)**

| Ekran | Ne yapar |
|---|---|
| **Welcome** | İki büyük seçenek: **"Yük Veriyorum"** ve **"Taşımacıyım"** → ilgili kayıt ekranı; altta "Zaten hesabım var → Giriş" |
| **Login** | `emailOrPhone`, `password`; sunucu hatalarını gösterir (401 genel mesaj, 423 kilit + kalan süre) |
| **RegisterShipper** | `fullName, email, phone, password, cityId (+ firma/vergi opsiyonel), KVKK onay kutusu` |
| **RegisterCarrier** | Ortak alanlar + `homeCityId`, **en az 1 araç** (tip, kapasite, plaka), çalışma illeri |

**Önemli noktalar**
- **`deviceId`:** İlk açılışta bir `UUID` üret, **Keychain'e kaydet**, her girişte aynısını gönder.
- **Form doğrulaması iki katmanlı:** iOS'ta hızlı geri bildirim ver (boş alan, şifre kuralı: 8+, büyük, küçük, rakam), ama **son söz sunucudadır**.
- **Sunucu hatalarını alanlara eşle:** 400 cevabında `errors["email"]`, `errors["vehicles[1].capacityKg"]` gibi anahtarlar gelir; her mesajı ilgili kutunun altına koy.
- **409:** "Bu e-posta/telefonla zaten bir hesap var" mesajını gösterir.
- İl/ilçe seçimini C5'teki **`LocationPickerView`'ı yeniden kullanarak** yap.
- **Roller:** Yük Veren ve Taşımacı ekranları birbirine karışmasın (rapor: iki ayrı kök).
- Kayıt başarılı olunca **giriş yapılmış sayılmaz**: kullanıcıyı giriş ekranına yönlendir ya da arka planda giriş çağır.

**Bitti sayılır:** Simülatörden iki tipte de kayıt olunabiliyor ve giriş yapılabiliyor (jeton `TokenStore`'a kaydedilir, D6 hazırsa).

---

## 7. D8: Otomatik giriş (D4 + D5 bitince)

Açılışta: Keychain'de jeton var mı? → Yoksa Login. Varsa geçerli mi? Süresi dolmuşsa `/auth/refresh`; başarılıysa role göre ana ekran (**Yük Veren TabView** / **Taşımacı TabView**); reddedilirse Keychain temizlenir, "Oturumunuz sona erdi" ile Login. **Ağ yoksa oturum silinmez.** Rapor §11.4'te algoritma adım adım yazılı.

---

## 8. Sonraki aşamalar (özet)

| Aşama | iOS işi | Backend şartı |
|---|---|---|
| **E5, E6** | Yük Veren: İlan Ver (çok adımlı form), İlanlarım, detay. Taşımacı: İlan listesi (sonsuz kaydırma, filtre) | Aşama E |
| **F5** | Taşımacı: Teklif ver, Tekliflerim. Yük Veren: gelen teklifler | Aşama F (**MVP sonu**) |
| G5, H3 | İş durumu, puan/yorum, favori | G, H |
| I5 | Push izni, APNs | I (ücretli Apple hesabı) |
| J2, J4 | "Bana yakın", emsal fiyat | J (düşük öncelik) |
| K3, K4 | Şikâyet/hesap silme, TestFlight, App Store | K (ücretli Apple hesabı) |
| L1 | Tasarım cilası (renk, tipografi, animasyon) | L |

---

## 9. Takıldığında bana nasıl yazarsın? (junior için pratik)

1. **Ne yapmaya çalışıyordun?** ("C4'te `APIClient.send` yazıyordum")
2. **Hangi dosya, hangi satır?** (ekran görüntüsü ya da kodu yapıştır)
3. **Ne oldu?** Hata mesajının **tamamı** (Xcode'da kırmızı hataya tıkla, metni kopyala).
4. **Ne bekliyordun?**

Ben de önce **mantığı** anlatır, sonra kodu birlikte yazarız. Her adımın sonunda commit atmayı unutma (küçük adım, sık commit).

---

## 10. Küçük sözlük

| Terim | Anlamı |
|---|---|
| **Codable** | JSON ↔ Swift `struct` dönüşümü |
| **async / await** | Beklemeli iş (ağ isteği) yazma biçimi |
| **@Observable / @MainActor** | Ekranın izlediği durum nesnesi / ana iş parçacığında çalış |
| **actor** | Aynı anda yalnız bir iş yapan güvenli nesne (jeton yenileme için) |
| **Keychain** | iOS'un güvenli kasası (jeton burada saklanır) |
| **ATS** | iOS'un `http://` adreslerini engelleyen güvenlik kuralı |
| **xcconfig** | Derleme ayarlarını (örn. API adresi) dosyada tutmak |
| **ProblemDetails** | Sunucunun standart hata cevabı biçimi |
| **Interceptor** | Her isteğe araya girip başlık ekleyen/yenileyen parça |
| **MVVM** | View (ekran) ↔ ViewModel (ekran durumu) ↔ Service (iş) ayrımı |
