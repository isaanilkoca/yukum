//
//  00_Rehber_Models_Notifications.swift — Models/Notifications — bildirim paketleri
//  (Bu dosyada kod yok; klasörün ilk dosyası olarak ne nerede olduğunu anlatır.)
//

// Kod yok, sadece alanlar.
//
//
//  AppNotification     gelen: listedeki bir bildirim (tür, başlık, metin, ilgili ilan/teklif, okundu mu, zaman). NotificationService.list döner; NotificationsViewModel saklar, NotificationsView çizer
//                      Ad "Notification" değil: Foundation'da aynı adlı tür var (NotificationCenter)
//  NotificationCount   gelen: {"count": n}. NotificationService.unreadCount yalnız sayıyı döner (zil rozeti)
//
//  SUNUCU: bildirim satırı olayla aynı işlemde yazılır (teklif, kabul/red, aşama, tamamlama, puan, ilan kaldırma). Sözleşme: docs/api/Notifications.md
