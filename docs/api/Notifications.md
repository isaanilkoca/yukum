# Sözleşme kartı: Uygulama içi bildirimler

Taban adres `/api/v1`, jeton gerekir. **İki rol de** kullanır; herkes yalnız **kendi** bildirimlerini görür ve okundu yapar. Anonim 401.

## Uçlar
- `GET /notifications?page=1&pageSize=20` → `{ items, page, pageSize, totalCount }`. En yeni üstte. `pageSize` 1–50 arasına çekilir.
- `GET /notifications/unread-count` → `{ "count": 3 }` (zil rozeti).
- `POST /notifications/{id}/read` → 204. **İdempotent:** zaten okunduysa da 204. Başkasının/olmayan bildirim **404** (varlığı sızdırılmaz).
- `POST /notifications/read-all` → 204. Okunmamış yokken de 204.

## Satır (`NotificationDto`)
```json
{ "id": "…", "type": "OfferReceived", "title": "Yeni teklif", "body": "“Un çuvalları” ilanı için 1.200 ₺ teklif geldi.",
  "listingId": "…", "offerId": "…", "isRead": false, "createdAt": "2026-11-11T21:00:00Z" }
```
`listingId` / `offerId` iOS'un dokununca ilgili ekrana gitmesi içindir (boş olabilir).

## Hangi olay kime bildirim yazar
| `type` | Olay | Alan kişi |
|---|---|---|
| `OfferReceived` | Teklif geldi ya da Taşımacı tutarı güncelledi ("Teklif güncellendi") | Yük Veren |
| `OfferAccepted` | Teklif kabul edildi | Taşımacı |
| `OfferRejected` | Teklif reddedildi ya da ilan başka teklife verildi | Taşımacı |
| `JobStageChanged` | Yük alındı / yolda / teslim edildi | Yük Veren |
| `JobCompleted` | İş tamamlandı | İşi **bitirmeyen** taraf |
| `ReviewReceived` | Puan/yorum yazıldı | Taşımacı |
| `ListingCancelled` | İlan kaldırıldı (Yük Veren kaldırınca ya da hesabını silince) | Teklif vermiş Taşımacılar |

Metinler karşı tarafın **adını/telefonunu içermez** (ilan başlığı ve tutar yeter). Bildirim, olayla **aynı işlemde** (transaction) yazılır; biri olmadan diğeri olmaz.

## Push'a hazırlık (şimdilik kapalı)
`Notifications.PushedAt` boş = telefona gönderilmedi. Push (APNs) ücretli Apple hesabı ister, henüz yok. Eklenince: cihaz jetonunu kaydeden bir uç + `PushedAt` boş satırları APNs'e gönderip dolduran arka plan işçisi. Tabloda değişiklik gerekmez.

## Hesap silme
Silinen kişinin **kendi** bildirimleri silinir; karşı taraflara giden bildirimler (örn. "İlan kaldırıldı") kalır.
