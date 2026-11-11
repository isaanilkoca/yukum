# Karar Kayıtları

## K-001 — Ürün adı ve kimlikler (25 Ekim 2026)
- **Ürün adı:** Yüküm
- **Kod adı / namespace:** `Yukum` (Türkçe karakter kodda kullanılmaz)
- **Bundle ID:** `com.isaanilkoca.yukum` (geçici; App Store ad müsaitliği yayın öncesi kontrol edilecek)
- **Neden:** Rapor Bölüm 1'deki öneri; kısa, aranabilir.

## K-010 — SQL Server sürümü (25 Ekim 2026)
- **Karar:** SQL Server **2025** (rapordaki 2022 yerine). Notlardaki gereksinim yalnız "MSSQL".
- **Neden:** `mcr.microsoft.com/mssql/server:2025-latest` yayında; hedef güncel teknoloji.
- **Not:** İmaj yalnız amd64; Apple Silicon'da Docker emülasyonuyla çalışıyor (rapor Bölüm 4.2'deki not).

## K-011 — A4 tasarım kararı ertelendi (25 Ekim 2026)
- **Karar:** Renk/font seçimi iOS projesi açılmadan önce (C3) verilecek.
- **Neden:** Backend'i etkilemiyor. Kural: ekranlarda sabit renk/font yazılmaz, yalnız tema değerleri (Rapor 21.1).

## K-012 — Kimlik (Id) üretimi: EF Core sıralı GUID (25 Ekim 2026)
- **Karar:** Tablo anahtarları `Guid`; değeri uygulama kodu değil EF Core'un SQL Server için sıralı GUID üreticisi atar.
- **Neden:** SQL Server `uniqueidentifier` değerlerini sondan sıralar; UUIDv7 (zaman başta) kümelenmiş indekste sıralı olmaz. Rapor 9.1 "UUIDv7 / sıralı GUID değerlendirilebilir" diyordu; ölçüt: indeks parçalanmasını azaltmak.
- **Sonuç:** Kayıt `Add` edilmeden `Id` boştur (`Guid.Empty`). Başka tablo gerektirmez; kayıt eklendikten sonra Id dolar.
- **Geri dönüş maliyeti:** Düşük (taban sınıfta tek alan).

## K-013 — İl/ilçe kimlikleri ve veri kaynağı (25 Ekim 2026)
- **Karar:** `Cities.Id` = plaka kodu (1–81); ayrı `PlateCode` sütunu yok (Id ile aynı, tekrar eden alan tutarsızlık riski). `Districts.Id` = sıralı tamsayı (plaka sırası, sonra Türkçe alfabetik); seed donduruldu, ileride eklenen ilçe sıradaki numarayı alır, mevcut numaralar değişmez.
- **Veri:** 81 il / 973 ilçe, `docs/veri/il-ilce.json`; kaynaklar, yöntem ve bulunan hatalar `docs/veri/Veri_Kaynaklari.md`.
- **Neden:** Rapor 9.5 "resmî listeden alınıp doğrulanır". Tek kaynağa güvenilmedi; 5 kaynak çapraz kontrol edildi ve Vikipedi'de 9, Wikidata'da 2 hata bulundu.
- **Rapordan fark:** Rapor `PlateCode` sütunu sayıyor; Id ile aynı olduğu için eklenmedi. DTO'da `id` plaka kodudur.
- **Geri dönüş maliyeti:** Düşük (seed migration'ı yeniden üretilir).

## K-014 — İl/ilçe tabloları `BaseEntity`'den türemez, seed JSON'dan okunur (25 Ekim 2026)
- **Karar:** `City` ve `District` kendi `int Id`'sine sahiptir (Id'yi veritabanı üretmez), `BaseEntity`'den türemez. Seed verisi koda kopyalanmaz: `docs/veri/il-ilce.json` derlemeye gömülür ve `GeographySeed` onu okur; `HasData` ile migration'a yazılır.
- **Neden:** `BaseEntity.Id` GUID'dir, K-013 plaka kodunu ve sıra numarasını Id yapar. İl ve ilçe kullanıcı tarafından oluşturulmayan, silinmeyen, değiştirilmeyen sabit veridir; `CreatedAt`, `IsDeleted`, `RowVersion` onlara anlam katmaz. Tek kaynak (JSON) verinin kodla ayrışmasını önler; testler veritabanını aynı JSON ile karşılaştırır.
- **Sonuç:** Aynı ilde aynı ilçe adı yoktur (benzersiz indeks `CityId + Name`); il adı benzersizdir; ilçe bir ile bağlıdır (`Restrict`: il silinirse ilçeleri sessizce silinmez).
- **Geri dönüş maliyeti:** Orta. Id türü sonradan değişirse migration ve ona bağlı ilan tabloları etkilenir.

## K-015 — İl/ilçe uçları: özel repository, iki katmanlı önbellek, ilk 404 hata türü (25 Ekim 2026)
- **Karar:** (1) İl/ilçe okuması genel `IRepository<T>` yerine özel `IGeographyRepository` ile yapılır. (2) Önbellek iki katmanlıdır: sunucuda `IMemoryCache` (24 saat; boş sonuç saklanmaz) ve istemci/ara katmanda `Cache-Control: public, max-age=86400`; 404 cevapları `no-store`. (3) "Kayıt yok" için `NotFoundException` (Application) → `GlobalExceptionHandler` 404 ProblemDetails (başlık "Bulunamadı", `detail` istemciye gösterilir). (4) İstemciye yalnız `id` ve `name` gider; koordinatlar sunucuda kalır.
- **Neden:** (1) `IRepository<T>` `BaseEntity` ve GUID Id ister; il/ilçe K-014 gereği değil. Arayüzün kendi belgesi "özel sorgular özel repository'ye" der. (2) Rapor "cache'lenir" ve `IMemoryCache` der; veri yalnız migration/yeni sürümle değişir. Boş sonucu saklamamak, anonim uca rastgele numara göndererek belleği şişirmeyi önler. (3) İlk 404 ihtiyacı; sonraki 403/409/422 aynı kalıpla eklenir. (4) Mesafe hesabı sunucuda yapılacağı için istemcinin koordinata ihtiyacı yok; kapsam eklememe kuralı.
- **Geri dönüş maliyeti:** Düşük. Yeni alan eklemek geriye dönük uyumludur; önbellek süresi tek sabittir.

## K-016 — Kimlik tabloları (Aşama D1) (25 Ekim 2026)
- **Karar:**
  1. Kullanıcı sınıfı `AppUser` (ASP.NET Core Identity, GUID anahtar) **Infrastructure**'dadır; Domain hiçbir pakete bağlı kalır. Profiller, araç ve jeton Domain'dedir ve kullanıcıya yalnız `UserId` (GUID) ile bağlanır; ilişkiler Infrastructure'daki yapılandırmada kurulur.
  2. Tablo adları raporla uyumlu: `Users`, `Roles`, `UserRoles`..., `ShipperProfiles`, `CarrierProfiles`, `Vehicles`, `RefreshTokens` (Identity'nin `AspNet...` adları değiştirildi).
  3. Çalışma bölgeleri raporun tek `ServiceRegions` sütunu yerine ayrı **`CarrierServiceCities`** tablosunda (taşımacı + il). Rapordan fark.
  4. Roller (`Admin`, `Shipper`, `Carrier`) sabit GUID'lerle seed edilir. Araç tipi: Tır=1, Kamyon=2, Kamyonet=3, Frigorifik=4, Diğer=99.
  5. E-posta ve telefon benzersizliği **veritabanı düzeyindedir** (benzersiz indeks; telefon boşsa filtrelenir). `KvkkAcceptedAt` kullanıcı kaydında tutulur. `CreatedAt/UpdatedAt` kuralı `ITimestamped` arayüzüyle kullanıcıya da uygulanır; yumuşak silme yalnız `BaseEntity` tablolarında kalır.
  6. Kullanıcı silinince profili, araçları, çalışma bölgeleri ve jetonları **gerçekten silinir** (cascade; hesap silme/KVKK için). İl bağlantıları `Restrict`.
- **Neden:** (1) Clean Architecture bağımlılık kuralı. (3) Metin içinde il numarası tutmak yabancı anahtar korumasını kaybettirir ve "şu ilde çalışanlar" sorgusunu zorlaştırır. (5) Uygulama katmanı atlansa bile veritabanı çift kaydı reddeder. (6) App Store hesap silme zorunluluğu ve KVKK.
- **Eklenmeyenler (kapsam):** `CarrierProfiles.CurrentLat/Lon` (konum özelliği gelince), `ShipperProfiles.DistrictId` (rapor tablosunda yok), e-posta doğrulama ve şifre sıfırlama (D planında yok).
- **Geri dönüş maliyeti:** Orta. Tablo adları ve Id türleri sonradan değişirse migration ve istemci etkilenir.

## K-017 — Kayıt uçları: şifre kuralı, telefon biçimi, tek işlem, hata biçimi (25 Ekim 2026)
- **Karar:**
  1. **Şifre:** 8–128 karakter, en az bir büyük harf, bir küçük harf, bir rakam; sembol zorunlu değil. Kural **tek yerde** (`PasswordPolicy`, Application) tutulur; hem kayıt doğrulaması (Türkçe mesajlar) hem Identity (`PasswordPolicyValidator`, ikinci savunma) aynı koddan okur. Identity'nin kendi büyük/küçük harf seçenekleri kapalıdır.
  2. ~~**Her e-posta tek hesap**~~ → **K-022 ile değişti: e-posta ve telefon ROL başına benzersiz.** **Telefon:** yalnız Türkiye cep telefonu; her yazılış `+905XXXXXXXXX` biçimine çevrilip saklanır ve benzersizdir. **E-posta:** küçük harfe çevrilip saklanır, benzersizdir. Bir e-posta/telefon tek hesaptur (Yük Veren ve Taşımacı arasında da).
  3. **Kayıt tek işlemdir** (kullanıcı + rol + profil + araçlar + çalışma illeri): bir adım başarısız olursa hiçbiri kaydedilmez. Eşzamanlı çift kayıt veritabanının benzersiz indeksi ile yakalanır ve 409'a çevrilir.
  4. **Taşımacı kaydında en az 1 araç zorunlu**, çalışma illeri opsiyoneldir. Yük Veren'de il zorunlu, ilçe saklanmaz (K-016).
  5. **Hata biçimi:** doğrulama → 400 (başlık "Doğrulama hatası", `errors` sözlüğü, camelCase alan adları, liste için `vehicles[1].capacityKg`); çakışma → 409 "Çakışma"; kayıt yok → 404. FluentValidation hataları ve MVC model hataları aynı 400 biçimini kullanır. Kayıt cevabı 201 + kullanıcı özeti; **oturum açılmaz** (giriş D3).
  6. Kayıt uçları `[AllowAnonymous]`; rol endpoint'ten gelir, gövdedeki `role/userType` yok sayılır.
- **Neden:** (1) Identity'nin ASCII-yalnız harf kontrolü "Şifre1234"ü reddedip 500 üretirdi; tek kaynak ayrışmayı önler. "En yaygın kural" (8+, büyük+küçük+rakam) kullanıcı tercihi. (2) Aynı numara/e-posta farklı yazılışla ikinci hesap açmasın; telefonla giriş (D3) için tek biçim şart. (3) Yarım hesap kalması (kullanıcı var, profil yok) tutarsız ve giriş sonrası çöker. (5) iOS her hatayı tek biçimde okur.
- **Eklenmeyenler (kapsam):** e-posta/telefon doğrulama, şifre sıfırlama, hız sınırı (D5'te).
- **Geri dönüş maliyeti:** Düşük (şifre kuralı tek sabit/sınıf). Telefon biçimi sonradan değişirse saklanan veriler dönüştürülmelidir.

## K-018 — Giriş (D3): kimlik çözme, kilit, jeton içeriği ve ayarları (25 Ekim 2026)
- **Karar:**
  1. **Giriş alanı** `emailOrPhone`: `@` içeriyorsa e-posta (küçük harf), değilse cep telefonu (`+905…` biçimine çevrilir); ikisi de değilse ayrı hata değil genel 401. `deviceId` zorunlu, `deviceName` opsiyonel (oturum jetonu cihaz bazlı olacağı için D4'ten önce sözleşmeye alındı).
  2. **Hatalı giriş tek cevap:** kullanıcı yok ve şifre yanlış aynı 401 ("E-posta veya şifre hatalı."); kullanıcı yokken de sahte hash'e karşı doğrulama yapılır (süre farkı). Hesap devre dışılığı (403) **yalnız doğru şifreden sonra** söylenir.
  3. **Kilit:** ~~5 hatalı denemede 15 dk~~ → **K-020 ile güncellendi: 10 hatalı denemede 5 dk**; kilit anındaki 5. denemeden itibaren **423** + `Retry-After` (saniye). Kilitliyken doğru şifre de reddedilir. Başarılı girişte sayaç sıfırlanır. Eşzamanlı yanlış denemeler sayımı ezmesin diye sayım birkaç kez yeniden denenir.
  4. **Erişim jetonu:** JWT, HS256, 15 dk, yalnız `sub`, `role`, `jti` (+ `iss`, `aud`, `iat`, `nbf`, `exp`); kişisel veri yok. Doğrulama: yalnız HS256, imza + yayıncı + hedef + süre, saat toleransı 30 sn. `role` claim'i rol olarak okunur.
  5. **Ayarlar:** `Jwt:Issuer`, `Jwt:Audience`, `Jwt:AccessTokenMinutes` `appsettings.json`'da; `Jwt:SigningKey` (≥32 karakter) **gizli**: user-secrets / ortam değişkeni. Eksik ya da kısa anahtar uygulama açılırken hata verir (`ValidateOnStart`).
  6. Giriş cevabında `refreshToken` **D4'e bırakıldı** (alan eklemek geriye dönük uyumlu); cevapta kullanıcı özeti `id`, `displayName`, `role`, `avatarUrl`.
  7. Hata eşlemeleri tek yerde: 401 `InvalidCredentialsException`, 403 `ForbiddenException`, 423 `AccountLockedException`.
- **Neden:** (2) Kayıtlı e-posta/telefon yoklamasını (kullanıcı numaralandırma) ve zamanlama saldırısını zorlaştırmak; rapor 6.2. (3) Kaba kuvvet denemesini yavaşlatmak; rapor 6.2. (4) Jeton şifreli değil imzalıdır, içeriği herkes okur: kişisel veri yazılmaz; algoritma kısıtı "alg" değiştirme saldırısını keser. (5) Anahtar sızarsa sahte giriş jetonu üretilebilir: repoya girmez, zayıf anahtarla sessizce başlamaz.
- **Eklenmeyenler (kapsam):** yenileme jetonu (D4), `/me` ve yetki politikaları, hız sınırı (D5), şifre sıfırlama, e-posta/telefon doğrulama.
- **Geri dönüş maliyeti:** Düşük. Jeton ömrü ve kilit kuralı sabit ayarlardır; yeni claim eklemek uyumludur.

## K-019 — Kayıtta il sorulmaz (4 Kasım 2026)
- **Karar:** `ShipperProfiles.CityId` ve `CarrierProfiles.HomeCityId` boş geçilebilir (`int?`); kayıt isteğinde `cityId` / `homeCityId` opsiyoneldir, verilirse geçerli bir il olmalıdır. iOS kayıt ekranları göndermez. **K-017 madde 4'ün "Yük Veren'de il zorunlu" kısmı bununla değişti.**
- **Neden:** Yük Veren'in ilanları kendi kalkış/varış ilini taşır, Taşımacı her yere gidebilir; profildeki il hiçbir sorguda kullanılmıyordu ve iOS sahte bir değer (34) gönderiyordu. Taşımacının çalıştığı iller zaten isteğe bağlı `CarrierServiceCities` tablosunda.
- **Uygulama:** migration `MakeProfileCityOptional`, doğrulama `OptionalExistingCity`, entegrasyon testi "ilsiz kayıt".
- **Geri dönüş maliyeti:** Düşük (sütunlar yeniden `NOT NULL` yapılırsa boş satırlar önce doldurulmalı).

## K-020 — Hesap kilidi gevşetildi: 10 deneme / 5 dakika (7 Kasım 2026)
- **Karar:** `MaxFailedAccessAttempts` 5 → **10**, `DefaultLockoutTimeSpan` 15 dk → **5 dk**. K-018 madde 3'ü günceller; 423 + `Retry-After` davranışı aynı.
- **Neden:** Gerçek kullanımda (test sırasında) birkaç yazım hatası hesabı 15 dakika kilitledi. Kullanıcı kilidin kolay devreye girmemesini istedi.
- **Güvenlik dengesi:** Kilit tek koruma değil; giriş/kayıt/yenileme uçlarında IP başına dakikada 30 istek hız sınırı da var. 5 dk kilitle saldırgan en çok dakikada ~2 şifre dener, 10 deneme sonrası beklemek zorunda. Parola politikası (en az 8 karakter, büyük/küçük/rakam) aynı.
- **Geri dönüş maliyeti:** Düşük (iki ayar sabiti). Canlıda kötüye kullanım görülürse sayılar sıkılaştırılır ya da her kilitte süre uzatılan (artan bekleme) yönteme geçilir.

## K-021 — Hesap silme = anonimleştirme, şifre onaylı, aktif işte engelli (11 Kasım 2026)
- **Karar:** `POST /api/v1/account/delete`. Kullanıcı satırı silinmez, kişisel alanlar boşaltılır ("Silinmiş Kullanıcı"); açık ilan/bekleyen teklifler temizlenir; favori ve görüntülenme kayıtları fiziksel silinir; tüm yenileme jetonları iptal. Hepsi tek işlemde (transaction).
- **Neden fiziksel silme değil:** Teklif, sohbet, puan ve ilan kayıtları karşı tarafın geçmişidir; silmek onların kayıtlarını bozar ve yabancı anahtar ilişkilerini kırar. Anonimleştirme hem KVKK/Apple "silme hakkı"nı karşılar hem tutarlılığı korur.
- **Şifre onayı:** Çalınmış bir jetonla hesap silinemesin diye. Yanlış şifre **400** (401 değil: iOS oturumu sonlandırmasın). Uç `"auth"` hız sınırı altında.
- **Aktif iş engeli (409):** Kabul edilmiş, tamamlanmamış işi olan silemez; karşı tarafı yarı yolda bırakmamak için.
- **Neden POST:** Gövdeli (şifre) DELETE isteklerini bazı istemci ve vekiller düşürür.
- **Kabul edilen kuyruk:** Erişim jetonu silindikten sonra en çok 15 dk geçerli (stateless); yenileme jetonları anında iptal.
- **Geri dönüş maliyeti:** Orta. Fiziksel silmeye geçmek yabancı anahtarları ve geçmiş ekranlarını yeniden tasarlamayı gerektirir.
- **Puan ve yorum silinmez (kullanıcı kararı, 11 Kasım):** Yük Veren hesabını silse de Taşımacı'nın puanı ve yorum metni kalır (itibar geçmişi; kullanıcılar geçmişte olanı görsün). Yalnız yazarın adı "Silinmiş Kullanıcı" olur. **İki yönde de geçerli:** silinen Taşımacı'nın işleri ve puanı Yük Veren'in geçmişinde ve `GET /carriers/{id}` profilinde, silinen Yük Veren'in işleri Taşımacı'nın geçmişinde kalır; karşı tarafa adı "Silinmiş Kullanıcı" görünür. Testler: `A_deleted_shipper_keeps_the_rating_and_comment...`, `Completed_jobs_stay_in_the_history_of_the_other_side...`.

## K-022 — Aynı e-posta/telefon iki rolde: bir Yük Veren + bir Taşımacı hesabı (11 Kasım 2026)
- **Karar:** Aynı kişi aynı e-posta ve telefonla hem Yük Veren hem Taşımacı olarak kayıt olabilir; **aynı role ikinci hesap açılamaz**. K-017/K-018'deki "bir e-posta = tek hesap" kuralını günceller.
- **İki ayrı hesap:** Şifre, hatalı deneme sayacı ve kilit, oturumlar, ilanlar/teklifler/puanlar, hesap silme birbirinden bağımsız. Birini kilitlemek ya da silmek diğerini etkilemez.
- **Veritabanı:** `Users` üzerinde `(NormalizedEmail, UserType)` ve `(PhoneNumber, UserType)` benzersiz indeksleri (eski tek sütunlu benzersiz indeksler kalktı). Identity'nin kendi benzersiz e-posta denetimi kapatıldı (`RequireUniqueEmail=false`); kontrol `AccountService`'te (rol başına) + indeks (yarış durumunda). Identity `UserName` tek başına benzersiz olmak zorunda: artık `e-posta_Rol` (örn. `ali@x.com_Shipper`). Mevcut hesaplar migration `EmailAndPhoneUniquePerRole` içindeki SQL ile yeni biçime taşındı.
- **Giriş:** `POST /auth/login` gövdesine `role` (`Shipper`/`Carrier`) eklendi; iOS giriş ekranında rol seçici. Rol yoksa ve tek hesap varsa o hesaba girilir; iki hesap varsa 400. Hesap varlığı yine yalnız doğru şifreden sonra anlaşılır (zamanlama ve mesaj eşitliği korunur).
- **Neden iki ayrı hesap, tek hesap + iki rol değil:** Mevcut model "kullanıcının tam bir rolü var" üzerine kurulu (JWT rolü, profiller, tüm yetki kontrolleri). Çok rollü tek hesap bunların hepsini yeniden yazmayı gerektirirdi; ayrı hesap, değişikliği kayıt ve girişe sınırlar.
- **Geri dönüş maliyeti:** Orta. İki rollü e-postalar varken eski tek sütunlu indekse dönmek mümkün değil (migration `Down` bunu belirtir).

## K-023 — Bildirimler: uygulama içi, olayla aynı işlemde yazılır, push'a hazır (12 Kasım 2026)
- **Karar:** Tek `Notifications` tablosu (kime, tür, başlık, metin, ilan/teklif, `ReadAt`, `PushedAt`). 4 uç: liste (sayfalı), okunmamış sayısı, okundu, hepsi okundu. Bildirimi **olayı yapan handler** aynı `SaveChanges`'te yazar (teklif/kabul/aşama/tamamlama/puan/ilan kaldırma/hesap silmede açık ilan).
- **Neden aynı işlemde:** "Teklif kaydedildi ama bildirim yazılamadı" tutarsızlığı olmaz (transactional outbox fikri). Metinler tek yerde (`NotificationFactory`).
- **Push (APNs) yok:** Apple'ın ücretli geliştirici hesabı gerekir. Tasarım buna hazır: `PushedAt` boş satırlar "gönderilecekler kutusu"; sonradan cihaz jetonu ucu + arka plan işçisi eklenir, tablo değişmez.
- **Neden arka plan işçisi (worker) yazılmadı:** Gönderilecek bir yer yok; kullanılmayan kod olurdu.
- **Gizlilik:** Metinler karşı tarafın adını/telefonunu içermez. Hesap silinince kişinin kendi bildirimleri silinir.
- **Sohbet mesajı bildirimi dışarıda:** Liste kalabalıklaşır; sohbetin zaten kendi ekranı var.
- **Geri dönüş maliyeti:** Düşük. Tür sayı olarak saklanır (sona ekle).

## K-024 — Push (APNs): outbox + arka plan işçisi, jeton tabanlı kimlik (12 Kasım 2026)
- **Durum değişti:** Apple Developer Program üyeliği alındı (Team ID 73H886HWW8); K-023'teki "push yok" kısmı kalktı.
- **Karar:** `DeviceTokens` tablosu (jeton benzersiz) + `PUT/DELETE /notifications/device-token`. Gönderim isteğin içinde DEĞİL: `PushWorker` (BackgroundService) `PushDispatcher` ile `Notifications.PushedAt` boş satırları APNs'e yollar.
- **Neden istek içinde göndermiyoruz:** Apple yavaş ya da erişilemezse kullanıcının isteği (teklif verme) beklemez/başarısız olmaz; bildirim satırı olayla aynı işlemde yazıldığı için hiçbir olay kaybolmaz, gönderim sonra yeniden denenir (transactional outbox).
- **Kimlik:** Sertifika (.p12, yılda bir yenilenir) yerine **jeton tabanlı** (.p8 anahtar, süresiz, tüm uygulamalarda geçerli). JWT ES256 elle üretilir (ek paket yok), 50 dk önbellek (Apple 20–60 dk ister).
- **Soyutlama:** İş kuralı `IPushSender` arayüzünü bilir, Apple'ı bilmez; testte sahte gönderici (gerçek Apple çağrısı yok).
- **Hata davranışı:** geçersiz jeton silinir; geçici hata sonraki turda; 1 saatten eski bildirim gönderilmez; telefonu olmayana gönderim yok.
- **Bilinen sınır:** Tek sunucu örneği varsayılır. İki örnek aynı anda çalışırsa aynı bildirim iki kez gidebilir; çoklu örnekte satırlar önce "sahiplenilmeli" (UPDATE ... OUTPUT ya da kilit). Vitrin projesinde gerek yok.
- **Gizli veri:** `.p8` repoda yok; yolu `Apns:KeyPath` ayarında (user-secrets / ortam değişkeni). `Apns:Enabled=false` varsayılan.
- **Geri dönüş maliyeti:** Düşük. `Apns:Enabled=false` push'u kapatır, uygulama içi bildirimler aynen çalışır.

