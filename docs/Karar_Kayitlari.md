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
