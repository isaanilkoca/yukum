import UIKit
import UserNotifications

// SwiftUI'da uygulama olayları (push adresi geldi, bildirime dokunuldu) View'lara gelmez; Apple bunları UIApplicationDelegate'e yollar.
// NEDEN SINIF + NSObject: bu Apple'ın UIKit dönemi sözleşmesi (UIApplicationDelegate); Objective-C tabanlı olduğu için struct olamaz, NSObject'ten türemek zorunda.
// delegate [SWIFT/UIKit kalıbı]: "olay olunca şu nesnenin şu fonksiyonunu çağır" | fonksiyon adları Apple'ın belirlediği adlardır, değiştirilemez.
// YukumApp bu sınıfı @UIApplicationDelegateAdaptor ile bağlar. Burada mantık yok: olay alınır, PushManager'a ya da anons panosuna aktarılır.
// BAĞLANTI: App/YukumApp.swift (bağlar) → Models/Notifications/PushManager (adres) | Views/HomeView (.onReceive: pushTapped, pushReceived)
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // Uygulama açılırken: bildirim olaylarını bu sınıf dinlesin
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Apple push adresini verdi (registerForRemoteNotifications'ın başarılı cevabı)
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { await PushManager.shared.didReceive(deviceToken: deviceToken) }
    }

    // Kayıt başarısız (simülatör, ağ yok, yetenek eksik): uygulama içi bildirimler yine çalışır
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Push kaydı başarısız: \(error.localizedDescription)")
    }

    // Uygulama AÇIKKEN bildirim geldi: varsayılan davranış hiçbir şey göstermemek; biz üstte şerit + ses istiyoruz
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        NotificationCenter.default.post(name: .pushReceived, object: nil) // HomeView zil sayısını tazeler
        return [.banner, .sound]
    }

    // Kullanıcı bildirime DOKUNDU: bildirim listesini aç
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        NotificationCenter.default.post(name: .pushTapped, object: nil)
    }
}
