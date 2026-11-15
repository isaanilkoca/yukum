//
//  00_Rehber_App.swift — App/ — UYGULAMANIN GİRİŞ KAPISI
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: Uygulama açılınca ilk çalışan dosyalar. İş mantığı yok; yalnız başlatma ve sistemle (bildirim) konuşma.
//
// DOSYALAR
//  YukumApp.swift         @main — program buradan başlar. Pencereyi açar, temayı (Sistem/Açık/Koyu) uygular.
//                         init(): "-uiTestReset" açılış bayrağı (YALNIZ DEBUG) → Keychain oturumu + son rol silinir (arayüz testleri temiz başlasın)
//  ContentView.swift      İlk ekran = Views/LoginView (otomatik girişi de o dener).
//  AppDelegate.swift      Push: APNs cihaz jetonu gelince PushManager'a verir; bildirime dokunulunca açılacak ekranı PushManager'a iletir.
//                         fn: application(didRegisterForRemoteNotificationsWithDeviceToken:), userNotificationCenter(didReceive:)
//  PrivacyInfo.xcprivacy  Apple gizlilik beyanı (hangi veri, neden). App Store şartı.
//
// ZİNCİR: YukumApp → ContentView → LoginView → (giriş başarılı) → HomeView
//         AppDelegate → Models/Notifications/PushManager → HomeView (bildirime dokununca ilgili liste açılır)
