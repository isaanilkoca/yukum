# Güvenlik kontrol listesi (K2) — 11 Kasım 2026

Her madde için: **durum** (Tamam / Kabul edilen risk / Canlıdan önce yapılacak), **nerede** ve **nasıl doğrulandı**.

## Kimlik ve oturum
| Konu | Durum | Nerede / Doğrulama |
|---|---|---|
| Şifre saklama | Tamam | ASP.NET Identity, PBKDF2 hash; düz şifre hiçbir yerde tutulmaz. Politika: 8–128 karakter, büyük + küçük harf + rakam |
| Kullanıcı yokken zamanlama farkı | Tamam | `AuthService`: kullanıcı yoksa da sahte hash doğrulaması (cevap süresinden hesap varlığı anlaşılmaz) |
| Giriş hata mesajı | Tamam | Tek genel mesaj ("E-posta veya şifre hatalı"); test: `AuthServiceTests` |
| Hesap kilidi | Tamam | 10 hatalı denemede 5 dk, 423 + `Retry-After` (K-020) |
| Hız sınırı | Tamam | Giriş/kayıt/yenileme/hesap silme: IP başına dakikada 30 (`"auth"` politikası) |
| Erişim jetonu (JWT) | Tamam | Yalnız HS256, imza + yayıncı + hedef + süre doğrulanır, 15 dk, `alg:none` reddedilir (`Program.cs`) |
| Yenileme jetonu | Tamam | 256 bit rastgele, DB'de yalnız SHA-256 özeti, her kullanımda döner (rotasyon), cihaza bağlı, eski jeton tekrar kullanılırsa tüm aile iptal (çalıntı tespiti) |
| JWT imza anahtarı | Tamam | Kodda yok: user-secrets / `Jwt__SigningKey` ortam değişkeni; yoksa uygulama açılmaz |

## Yetkilendirme
| Konu | Durum | Nerede / Doğrulama |
|---|---|---|
| Yetkisiz uç yok | Tamam | `AuthorizationMatrixTests`: tüm uçlar uygulamadan okunur; anonim uç yalnız açık izin listesinde olabilir, aksi hâlde test kırılır (`[Authorize]` silinince kırıldığı elle denendi) |
| Rol kontrolü | Tamam | Aynı testte her korumalı uç: anonim → 401, yanlış rol → 403, doğru rol → geçer |
| Başkasının verisine erişim (IDOR) | Tamam | Sahiplik handler'da denetlenir; başkasının kaydı için **404** (varlığı sızdırılmaz). Entegrasyon testleri: ilan, teklif, sohbet, puan, istatistik |
| Mass assignment | Tamam | Kullanıcı kimliği (`ShipperId`, `CarrierId`) hep jetondan; istemci gövdesinden alınmaz |

## Girdi ve veri
| Konu | Durum | Nerede / Doğrulama |
|---|---|---|
| SQL injection | Tamam | Tüm sorgular EF Core/LINQ (parametreli); kodda ham SQL yok (`FromSql`/`ExecuteSql` taraması boş) |
| Girdi doğrulama | Tamam | FluentValidation her komutta, Türkçe 400; veritabanında da CHECK/benzersiz indeks (puan 1–5, çifte yorum/favori) |
| İstek gövdesi boyutu | Tamam | En çok 1 MB (`Kestrel MaxRequestBodySize`) |
| Hata cevapları | Tamam | `ProblemDetails`; 500'de iç ayrıntı yok, yalnız `traceId`; ayrıntı sunucu logunda |
| Güvenlik başlıkları | Tamam | `X-Content-Type-Options: nosniff`, `Cache-Control: no-store`; test: `Responses_carry_the_security_headers` |
| Günlüklerde gizli veri | Tamam | Serilog istek günlüğü yalnız yöntem + adres + durum + süre yazar; gövde, şifre, jeton yazılmaz |

## Gizli bilgiler ve bağımlılıklar
| Konu | Durum | Nerede / Doğrulama |
|---|---|---|
| Parola/anahtar Git'te mi | Tamam | Bağlantı dizesi ve JWT anahtarı user-secrets; Docker için `.env` (`.gitignore`'da), şablon `.env.example` |
| Açıklı bağımlılık | Tamam | `dotnet list package --vulnerable --include-transitive`: tüm projelerde 0 (11 Kasım) |
| API deneme sayfası | Tamam | Scalar/OpenAPI yalnız `Development` ortamında |

## KVKK ve kullanıcı hakları
| Konu | Durum | Nerede |
|---|---|---|
| Açık rıza kaydı | Tamam | Kayıtta `kvkkAccepted` zorunlu, onay zamanı saklanır |
| Silme hakkı | Tamam | `POST /api/v1/account/delete`: şifre onayı, anonimleştirme (K-021) |
| Silinen veride tutulan | Bilinçli | Karşı tarafın kaydı olan teklif/sohbet/puan satırları kalır ama kişi "Silinmiş Kullanıcı"dır; favori ve görüntülenme izleri tamamen silinir |

## Kabul edilen riskler (bilerek, gerekçeyle)
1. **Erişim jetonu hesap silindikten sonra en çok 15 dk geçerli kalır.** Jetonlar durumsuz (stateless); her istekte DB'ye "hesap aktif mi" sormak maliyetli. Yenileme jetonları anında iptal olur, yani 15 dk sonra tamamen kapanır.
2. **Kayıt ucu "bu e-posta/telefon zaten kayıtlı" der** (hesap varlığı öğrenilebilir). Kullanıcıya net hata vermek için seçildi; IP hız sınırı toplu taramayı yavaşlatır.
3. **Genel (giriş dışı) uçlarda hız sınırı yok.** Mobil uygulama için şimdilik yeterli; canlıda ters vekil (reverse proxy) katmanında sınır konur.

## Canlıdan önce yapılacaklar (şimdi gerekmez)
- DB parolası ve JWT anahtarını **yenile** (geliştirmede kullanılanlar canlıya taşınmaz).
- HTTPS'i ters vekilde sonlandır, **HSTS** başlığını orada ekle; `ASPNETCORE_ENVIRONMENT=Production`.
- E-posta/telefon doğrulama ve iki adımlı doğrulama (2FA) isteğe bağlı iyileştirme.
- Yedekleme: `BACKUP DATABASE Yukum TO DISK = '/var/opt/mssql/backup/yukum.bak'` (günlük zamanlanmış) ve geri yükleme provası; volume ayrıca yedeklenir.

## İndeks ve sorgu kontrolü (K2)
- **Kural:** bileşik indeks yalnız **sol sütundan** başlayan aramaya yarar. `Offers (ListingId, CarrierId)` benzersiz indeksi "ilana göre" aramayı karşılar, "yalnız Taşımacı'ya göre" aramayı **karşılamaz**.
- **Bulunan boşluk:** Taşımacı ana sayfası her açılışında okunmamış rozet için `Offers.CarrierId` ile arıyor; indeks yoktu. Eklendi: `IX_Offers_CarrierId_Status`.
- Eklenenler (migration `AddOfferAndReviewIndexes`): `Offers (CarrierId, Status)`, `Offers (Status, DecidedAt)` (emsal fiyat), `Reviews (ShipperId)` (geçmişte "puan verdim").
- Açık ilan listesi indeksleri E4'te eklendi (`Listings (Status, CreatedAt)`, `(Status, ToCityId, CreatedAt)`); 2.025 ilanda sayfa sorguları 6–76 ms ölçüldü.
