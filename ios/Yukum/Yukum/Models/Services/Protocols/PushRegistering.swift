import Foundation

// Push kaydının SÖZLEŞMESİ | HomeViewModel sisteme (izin penceresi, Apple kaydı) doğrudan dokunmaz, bu sözleşmeyi çağırır → testte sahtesi verilir
// GERÇEK: Models/Notifications/PushManager.swift | SAHTESİ: YukumTests/Support/FakePush.swift | KULLANAN: ViewModels/HomeViewModel
protocol PushRegistering {
    func enable() async // giriş yapılınca: izin iste + Apple'a kaydol + adresi sunucuya gönder
    func unregister() async // çıkıştan hemen önce: adresi sunucudan sil (çıkan kullanıcıya bildirim gitmesin)
    func setBadge(_ count: Int) // uygulama simgesindeki kırmızı sayı
}
