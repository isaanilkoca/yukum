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
