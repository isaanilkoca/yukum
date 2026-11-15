-- Şikâyetler ve engellemeler (15 Kasım). Yönetici paneli gelene kadar şikâyetler buradan incelenir.
-- VS Code mssql ile Yukum veritabanında çalıştır.

-- 1) Son şikâyetler: kim, kimi, neden (1 Dolandırıcılık, 2 Hakaret/taciz, 3 Sahte ilan, 4 Spam, 99 Diğer), hangi ilan/sohbetten
SELECT r.CreatedAt, ru.FullName AS SikayetEden, tu.FullName AS SikayetEdilen, r.Reason, r.Note, r.ListingId, r.OfferId
FROM UserReports r
JOIN Users ru ON ru.Id = r.ReporterId
JOIN Users tu ON tu.Id = r.ReportedUserId
ORDER BY r.CreatedAt DESC;

-- 2) En çok şikâyet edilenler
SELECT tu.FullName, tu.Email, COUNT(*) AS Sikayet
FROM UserReports r JOIN Users tu ON tu.Id = r.ReportedUserId
GROUP BY tu.FullName, tu.Email ORDER BY Sikayet DESC;

-- 3) Engellemeler (engel iki yönlü işler)
SELECT b.CreatedAt, bu.FullName AS Engelleyen, tu.FullName AS Engellenen
FROM UserBlocks b JOIN Users bu ON bu.Id = b.BlockerId JOIN Users tu ON tu.Id = b.BlockedId
ORDER BY b.CreatedAt DESC;
