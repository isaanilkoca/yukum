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

## Push (telefon bildirimi, APNs)
- `PUT /notifications/device-token` gövde `{ "token": "<onaltılık APNs jetonu>", "deviceId": "<uygulamanın cihaz kimliği>", "sandbox": true }` → 204. **İdempotent:** her uygulama açılışında gönderilir. Aynı telefonda başka hesap giriş yaparsa adres o hesaba geçer. 400: jeton onaltılık değil / 64 karakterden kısa, `deviceId` boş.
- `DELETE /notifications/device-token?deviceId=...` → 204. **Çıkış yapmadan hemen önce** çağrılır (jeton gerektiği için önce bu, sonra `/auth/logout`). Kayıt yoksa da 204.
- `sandbox`: Xcode'dan kurulan geliştirme sürümü `true`, TestFlight/App Store `false` (Apple'ın iki ayrı sunucusu var; yanlış ortam = BadDeviceToken).

**Sunucu tarafı:** Bildirim satırı olayla aynı işlemde yazılır (`PushedAt` boş). Arka plan işçisi (`PushWorker`, `Apns:PollSeconds` aralıkla) `PushDispatcher` ile bekleyenleri gönderir ve `PushedAt`'i doldurur. Geçersiz jeton silinir; geçici hata sonraki turda yeniden denenir; 1 saatten eski bildirim telefona gitmez (listede durur); telefonu kayıtlı olmayana gönderim yapılmaz.

**Push yükü:** `aps.alert.title/body`, `aps.badge` = okunmamış sayısı, `aps.sound`; ayrıca `notificationId`, `type`, `listingId`, `offerId` (dokununca yönlendirme).

**Ayar (`Apns` bölümü):** `Enabled` (varsayılan `false`: işçi çalışmaz), `KeyPath` (.p8 dosya yolu), `KeyId`, `TeamId`, `BundleId`, `PollSeconds`. Geliştirmede user-secrets, canlıda ortam değişkeni. `.p8` dosyası repoya konmaz.

## Hesap silme
Silinen kişinin **kendi** bildirimleri ve telefon push adresleri silinir; karşı taraflara giden bildirimler (örn. "İlan kaldırıldı") kalır.
