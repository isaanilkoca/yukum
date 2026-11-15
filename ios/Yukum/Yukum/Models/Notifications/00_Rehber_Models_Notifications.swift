//
//  00_Rehber_Models_Notifications.swift — Models/Notifications/ — BİLDİRİMLER VE PUSH
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: Uygulama içi bildirim listesi (zil) + telefona düşen push bildiriminin kayıt/izin işleri.
//
//  AppNotification.swift       AppNotification {id, type, title, body, listingId?, offerId?, isRead, createdAt}
//                                ← GET /api/v1/notifications?page=…  (sayfalı)
//                              NotificationCount {count} ← GET /api/v1/notifications/unread-count (zil rozeti)
//                              type örnekleri: OfferReceived, OfferAccepted, OfferRejected, JobStageChanged, JobCompleted,
//                                              ReviewReceived, ListingCancelled, CancelRequested/Approved/Rejected
//  RegisterDeviceRequest.swift {token, deviceId, sandbox} → PUT /api/v1/notifications/device-token (bu telefona push gönderilsin)
//  PushManager.swift           izin + APNs jetonu yönetimi (PushRegistering protokolünü uygular):
//                                askPermissionAndRegister() — izin ister (giriş SONRASI, değer görüldükten sonra)
//                                didReceive(deviceToken:) — AppDelegate'ten gelen jetonu sunucuya kaydeder (hex(), sendIfReady)
//                                unregister() — çıkışta DELETE /notifications/device-token?deviceId=… (çıkan kişiye push gitmez)
//                                setBadge(_:) — uygulama simgesindeki sayı · noteTap()/takePendingTap() — bildirime dokunuldu mu
//
// ZİNCİR (push): backend olayı (teklif geldi) → Notifications tablosu → PushWorker → Apple (APNs) → telefon
//                → dokunulunca AppDelegate → PushManager.noteTap → HomeView ilgili listeyi açar
// KULLANAN: Services/NotificationService → NotificationsViewModel, HomeViewModel (rozet, enablePush)
