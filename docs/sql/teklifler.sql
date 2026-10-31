-- Yüküm: teklif akışını elle görmek için sorgular (VS Code mssql eklentisi, DB: Yukum).
-- Offers tablosunda ham numaralar vardır; adlar için JOIN gerekir.

-- 1) Tüm teklifler: hangi ilan, hangi taşımacı, ne durumda
SELECT o.Id, l.Title AS Ilan, u.FullName AS Tasimaci, o.Amount AS Tutar,
       CASE o.Status WHEN 1 THEN 'Beklemede' WHEN 2 THEN 'Kabul' WHEN 3 THEN 'Red' END AS Durum,
       o.DecidedAt AS KararAni, o.CarrierSeen AS TasimaciGordu,
       o.HiddenByCarrier AS TasimaciSildi, o.HiddenByShipper AS YukVerenSildi
FROM Offers o
JOIN Listings l ON l.Id = o.ListingId
JOIN Users u ON u.Id = o.CarrierId
ORDER BY o.CreatedAt DESC;

-- 2) İlanlar ve teklif sayıları
SELECT l.Title AS Ilan, c1.Name + ' → ' + c2.Name AS Rota,
       CASE l.Status WHEN 1 THEN 'Açık' WHEN 2 THEN 'Atandı' END AS IlanDurumu,
       COUNT(o.Id) AS TeklifSayisi
FROM Listings l
JOIN Cities c1 ON c1.Id = l.FromCityId
JOIN Cities c2 ON c2.Id = l.ToCityId
LEFT JOIN Offers o ON o.ListingId = l.Id
GROUP BY l.Title, c1.Name, c2.Name, l.Status;

-- 3) Taşımacıda "yeni karar" bekleyenler (bildirim rozeti sayısı)
SELECT u.FullName AS Tasimaci, COUNT(*) AS GorulmemisKarar
FROM Offers o JOIN Users u ON u.Id = o.CarrierId
WHERE o.Status <> 1 AND o.CarrierSeen = 0 AND o.HiddenByCarrier = 0
GROUP BY u.FullName;
